# Pipeline & Gates — Detailed Implementation Reference

Source: Cloudflare Glasswing blog (May 2026), Anthropic red.anthropic.com (April 2026),
FareedKhan claude-mythos-architecture, Anthropic Cookbook vulnerability detection agent.

---

## STAGE 1: RECON — Architecture & Task Queue Generation

### What Mythos Actually Does
From Cloudflare: "An agent reads the repository from the top down, fans out to subagents
responsible for each subsystem, and produces an architecture document covering build commands,
trust boundaries, entry points, and likely attack surface. It also generates the initial
queue of tasks for the next stage."

### Implementation
```
1. READ target top-down:
   - For source code: scan directory structure, README, build files
   - For web app: crawl, download JS, map endpoints, identify tech stack
   - For binary: decompile (Ghidra), reconstruct source, identify entry points
   - For network service: capture traffic, identify protocol, map handlers

2. PRODUCE architecture document:
   - Build commands (how to compile/run)
   - Technology stack (exact versions)
   - Trust boundaries (unauthenticated → authenticated → admin → system → kernel)
   - Entry points (every place attacker input enters)
   - Attack surface (entry points × trust boundaries × data flows)

3. FILE RANKING (source code targets):
   Score 5: Parses untrusted network input, handles auth, deserializes, kernel syscall handlers
   Score 4: Complex state machines, concurrency, memory management, crypto
   Score 3: Business logic, access control, session management
   Score 2: Utility functions with some external input
   Score 1: Constants, config, generated code — SKIP

4. GENERATE task queue:
   For each high-ranked file/endpoint:
     Task = { attack_class: "SQLi|SSTI|IDOR|...", scope: "file/endpoint/function", hint: "observed pattern" }
   Priority: file rank × attack class applicability
```

### Output Format
```
## RECON — [TARGET]
### Architecture: [tech stack, build, deploy]
### Trust Boundaries: [boundary map]
### Entry Points: [list with input types]
### Attack Surface: [entry points × trust boundaries]
### Task Queue: [prioritized list of (attack_class, scope, hint)]
```

---

## STAGE 2: THREAT MODEL — Structured Artifact

### Why This Exists
From Anthropic Cookbook: "Bootstrap phase produces formal threat model with: context, assets,
entry points & trust boundaries, threats, and OPEN QUESTIONS the code can't answer."

Without threat model, hunting WANDERS (Cloudflare lesson #1).

### Implementation
```
## THREAT MODEL — [TARGET]

### ASSETS (apa yang dilindungi)
- User data (PII, credentials, sessions)
- System integrity (file system, kernel, configuration)
- Service availability (uptime, resources)
- Internal services (databases, caches, queues)

### TRUST BOUNDARIES
- Public internet → Web server (TLS termination)
- Web server → Application (auth middleware)
- Application → Database (connection credentials)
- Userspace → Kernel (syscall boundary)
- Container → Host (namespace/cgroup boundary)
- Per endpoint: which boundary SHOULD apply?

### ENTRY POINTS
| Entry Point | Input Type | Validation | Trust Level |
|-------------|-----------|------------|-------------|
| GET /api/users | query params | partial | authenticated |
| POST /api/upload | multipart file | extension check | authenticated |
| TCP :2049 (NFS) | RPC packets | protocol parsing | unauthenticated |

### THREATS (hypothesis per entry point × attack class)
| Entry Point | Attack Class | Hypothesis | Priority |
|-------------|-------------|------------|----------|
| /api/users?sort= | SQLi | ORDER BY clause, no parameterization | HIGH |
| /api/upload | File upload bypass | Extension check only, no magic bytes | MEDIUM |

### OPEN QUESTIONS (MUST answer via testing)
- [ ] Does auth middleware apply to ALL /api/* routes?
- [ ] Is /api/v1 still active with different auth?
- [ ] What deserialization library is used for session data?
- [ ] Does the WAF inspect request body or only URL?
```

OPEN QUESTIONS become PRIORITY hypotheses for Stage 3 HUNT.

---

## STAGE 3: HUNT — Hypothesis-Driven Parallel Testing

### Key Principles (from Cloudflare)
- "Many narrow tasks in parallel, not one exhaustive agent"
- "Each task is one attack class paired with a scope hint"
- "Narrow scope produces better findings" — Cloudflare lesson #1

### Hypothesis Record Format
```
### Hypothesis H-[N]
- **Target**: [endpoint/function/file]
- **Class**: [attack class]
- **Statement**: "If I [action], then [expected outcome] because [reasoning from code reading]"
- **Status**: open | testing | confirmed | refuted
- **Evidence**: [request/response/crash/output]
- **WHY** (if refuted): [exact reason — filter? validation? different code path?]
```

### Tracking Table (maintain during hunt)
```
| ID | Target | Class | Status | Evidence Summary |
|----|--------|-------|--------|-----------------|
| H-1 | /api/users?sort= | SQLi | testing | 500 on single quote, investigating |
| H-2 | /api/upload | File bypass | refuted | Server validates magic bytes, not just extension |
| H-3 | /api/v1/admin | Auth bypass | confirmed | No auth middleware on v1 endpoints |
```

---

## STAGE 4: VALIDATE — Adversarial Disproof

### The Cloudflare Pattern
"An independent agent re-reads the code and tries to disprove the original finding.
It uses a different prompt and has no ability to emit new findings of its own."

### Adversarial Validation Protocol
```
FOR EACH confirmed hypothesis:

SWITCH to SKEPTIC perspective:
  "My ONLY job is to prove this finding is FALSE POSITIVE."

  1. RE-READ the code path independently
  2. CHECK: Is the PoC actually triggering the INTENDED vulnerability?
     (Not a different bug, not a test artifact, not expected behavior)
  3. CHECK: Is the impact as severe as claimed?
     (RCE claimed but only DoS? Auth bypass claimed but only info leak?)
  4. CHECK: Does the PoC work CONSISTENTLY? (run 3-5 times)
  5. CHECK: Are there MITIGATIONS not accounted for?
     (Stack canary? ASLR? WAF? Rate limiting? Input sanitization missed?)
  6. CHECK: Is this a KNOWN issue already patched in target version?
  
  VERDICT:
  - CANNOT REFUTE → HIGH CONFIDENCE finding
  - PARTIALLY REFUTED → DOWNGRADE severity/tier
  - FULLY REFUTED → DISMISS (record WHY in dead_ends)
```

### FareedKhan 2-of-3 Corroboration (for critical findings)
Send hypothesis to 3 different reasoning angles:
1. Code-level: "Does the code actually do what the PoC claims?"
2. Impact-level: "What's the REAL worst case, not theoretical?"  
3. Mitigation-level: "What defenses exist that might prevent exploitation?"
Majority (2/3) must agree for finding to proceed.

---

## STAGE 5: TRACE — Reachability Verification

### The Cloudflare Pattern
"For each confirmed finding, a tracer agent decides whether attacker-controlled input
actually reaches the bug from outside the system. Turns 'there is a flaw' into
'there is a reachable vulnerability.'"

### Reachability Check Protocol
```
FOR EACH validated finding:

1. IDENTIFY the vulnerable sink (exact function, exact line)
2. TRACE BACKWARDS from sink to entry point:
   sink ← caller ← caller ← ... ← entry point ← attacker input
3. AT EACH HOP check:
   - Is this call reachable in normal execution? (not dead code)
   - Is there a sanitizer/validator between this hop and the next?
   - Can attacker influence the VALUE that reaches this hop?
4. DOCUMENT the complete path:
   Attacker input → [entry] → [transform1] → [validate?] → [transform2] → [sink]
5. VERIFY end-to-end: send crafted input at entry → observe it reach sink
   (via debug output, debugger breakpoint, or behavioral change)

VERDICT:
- PATH CONFIRMED + INPUT REACHES SINK → REACHABLE (this is a vulnerability)
- PATH BROKEN at [hop N] → UNREACHABLE (this is a flaw, not a vuln)
  Record WHERE path breaks → might be bypassable → investigate
```

### Web Application Reachability
```
Specific checks for web targets:
- Does the route require authentication? Can we bypass?
- Does a WAF/proxy intercept before reaching the app?
- Is the parameter actually USED in the vulnerable code path?
- Is the function only called from admin-only routes?
- Is there a content-type restriction preventing our payload format?
```

### Kernel/Binary Reachability
```
Specific checks for low-level targets:
- Can unprivileged user trigger the syscall/ioctl?
- Is the vulnerable module loaded on default configurations?
- Does reaching the bug require capabilities (CAP_NET_ADMIN, etc.)?
- Is the code path gated by SELinux/AppArmor policy?
- Does KASLR/SMEP/SMAP prevent the exploit approach?
```

---

## STAGE 6: GAPFILL — Coverage Completion

### Why This Exists (Cloudflare)
"Hunters flag areas they touched but didn't cover thoroughly. Those areas get
re-queued for another pass. Counteracts the model's tendency to drift toward
attack classes it has already had success with."

### Implementation
```
After each HUNT pass, review:
1. Which files/endpoints in the task queue were NOT tested?
2. Which were tested with only 1-2 attack classes (minimum is 5 per H7)?
3. Which had PARTIAL results (interesting responses but no confirmed finding)?
4. Which attack classes were NOT tried on ANY target?

Generate new task queue:
- Untested items → high priority
- Partially tested → medium priority (specify WHICH classes to add)
- Tested but with interesting partials → medium priority (deeper investigation)
```

---

## STAGE 7: DEDUPE — Variant Consolidation

### Implementation
```
FOR all confirmed findings:
1. GROUP by root cause:
   - Same vulnerable function → single finding (note all call sites)
   - Same pattern in different functions → variant analysis record
   - Same bug class in different modules → each is separate finding
   
2. COLLAPSE duplicates:
   - Multiple XSS in same template engine → one finding + list of endpoints
   - Same SQLi pattern in 5 controllers → one finding + impacted list
   - Same auth bypass on 3 API versions → one finding + version matrix

3. RECORD variants (don't discard — they show SCOPE of the issue):
   "Root cause: [description]. Affected: [list of locations]."
```

---

## STAGE 8: CHAIN & REPORT — Primitive Assembly + Feedback Loop

### Chain Building Protocol
```
1. INVENTORY all confirmed+reachable findings
2. MAP each to PRIMITIVE:
   | Finding | Primitive |
   |---------|-----------|
   | Info disclosure | READ [what] |
   | IDOR | ACCESS [resource] as [role] |
   | XSS | EXECUTE JS in [context] |
   | SSRF | REACH [internal service] |
   | File upload | WRITE [file] at [location] |
   | Race condition | BYPASS [limit/check] |
   | SQLi | READ/WRITE [database] |
   
3. IDENTIFY gaps: "What primitive is MISSING for full impact?"
   Punya read tapi perlu write → hunt write primitive
   Punya SSRF tapi perlu creds → check cloud metadata
   
4. ASSEMBLE chain: order matters — each step enables the next
5. TEST end-to-end: full chain must work in single execution
6. VERIFY each link is LOAD-BEARING: re-run chain with each link disabled
```

### Feedback Loop (Cloudflare Stage 7)
"Reachable traces become new hunt tasks in the consumer repositories
where the bug is actually exposed. Closes the loop."

```
After chain construction:
- Did chain reveal NEW attack surface? → feed back to Stage 1
- Did chain expose NEW entry points? → feed back to Stage 3
- Did chain show ALTERNATIVE paths? → feed back to Stage 6
```

---

## PATHOLOGY DETECTION — Detailed Behavioral Monitors

### Source
FareedKhan architecture Component C4: "Self-Monitor + Deliberative Gate.
Five detectors map to incidents in the Claude Mythos Preview System Card."

### Detection & Response

**STUCK Detector**
```
Signal: >5 attempts on same hypothesis without progress
Check: "Am I trying the same approach repeatedly?"
Response:
  1. STOP immediately
  2. RCA: WHY specifically is each attempt failing?
  3. Extract INFORMATION from failures (what did I LEARN?)
  4. Pivot to genuinely different angle (not variation of same)
  5. If 3 angles failed → escalate to next attack class
```

**LOOP Detector**
```
Signal: Attempting payload that matches entry in dead_ends
Check: "Have I tried this before?" (check GAGAL section in memory)
Response:
  1. STOP — do NOT send the payload
  2. READ dead_ends for this target
  3. Understand WHY previous attempt failed
  4. Design approach that AVOIDS the same failure mode
  5. Only proceed if genuinely different
```

**DRIFT Detector**
```
Signal: Switching attack class before current class exhausted
Check: "Have I met minimum depth requirements (E2) for current class?"
Response:
  1. STOP pivot
  2. Check: 10+ variations tried? Understand WHY each failed?
  3. If NO → return to current class, complete requirements
  4. If YES → document learnings, pivot allowed
```

**SPRAY Detector**
```
Signal: Sending payloads without prior code reading or hypothesis
Check: "Do I have a hypothesis for WHY this payload should work?"
Response:
  1. STOP payload generation
  2. READ the target code/response for this endpoint
  3. UNDERSTAND: what does this endpoint DO?
  4. FORMULATE hypothesis: "Because of [observation], [payload] should [effect]"
  5. Only THEN send targeted payload
```

**HALLUCINATION Detector**
```
Signal: Claiming vulnerability without executable PoC or output evidence
Check: "Do I have ACTUAL output proving this works?"
Response:
  1. STOP claiming
  2. BUILD minimal PoC (curl command, Python script)
  3. RUN the PoC
  4. READ the complete output
  5. Only claim if output PROVES the vulnerability
```

---

## MEMORY INTEGRATION — Detailed Writeback Protocol

### Event-Driven Writeback
```
DURING entire pipeline, writeback is EVENT-DRIVEN (not batched):

STAGE 1 (RECON):
  → Save architecture doc to RECON section
  → Save task queue (for recovery after compaction)

STAGE 2 (THREAT MODEL):
  → Save threat model to INFO section
  → Save open questions to RECON section

STAGE 3 (HUNT):
  → Each confirmed hypothesis → EXPLOIT section (SEGERA)
  → Each refuted hypothesis → GAGAL section with WHY (SEGERA)
  → Each credential found → CREDENTIAL section (SEGERA)
  → Each new endpoint discovered → RECON section

STAGE 4-5 (VALIDATE + TRACE):
  → Update hypothesis status in EXPLOIT/GAGAL
  → Reachability results update finding records

STAGE 6-8 (GAPFILL + DEDUPE + CHAIN):
  → Chain constructions → EXPLOIT section
  → Gap analysis results → update task queue in LIVE STATUS
  → Final report → EXPLOIT section
```

### Recovery After Compaction
```
Post-compaction, to resume:
1. memory_get (UNLOCK) → get runbook
2. Read .md bertahap → restore full context
3. Check LIVE STATUS → what was last action?
4. Check GAGAL → what NOT to repeat
5. Check task queue → what's next
6. Resume from where we left off
```

---

## TASK VERIFIER — Mechanical Oracle Implementation

Source: red.anthropic.com/2026/firefox — "a trusted method of confirming whether
an AI agent's output actually achieves its goal. Task verifiers give the agent
real-time feedback as it explores, allowing it to iterate deeply until it succeeds."

### Why This Eliminates False Positives
```
WITHOUT oracle: Model REASONS about whether code is vulnerable
  → Reasoning can hallucinate → false positives
  → "This MIGHT be vulnerable because..."

WITH oracle: Model RUNS code and OBSERVES actual behavior
  → Mechanical verification → zero hallucination possible
  → "ASan reported heap-buffer-overflow at line 247" = FACT

Anthropic result: 112 Firefox reports, ALL true positives.
Because every single one was verified by crash/ASan BEFORE reporting.
```

### Oracle Selection per Target
```
MEMORY CORRUPTION (C/C++/Rust unsafe):
  Compile: gcc/clang -fsanitize=address,undefined -g target.c
  Run: ./target < crafted_input
  Oracle: ASan output → "ERROR: AddressSanitizer: heap-buffer-overflow"
  CONFIRMED if ASan fires. NO ASan = not confirmed (even if code looks vulnerable)

KERNEL:
  Build: make CONFIG_KASAN=y
  Trigger: run PoC in VM
  Oracle: dmesg | grep "KASAN\|BUG\|kernel panic"

WEB APPLICATION:
  Baseline: curl endpoint with normal input → save response
  Test: curl endpoint with exploit input → save response
  Oracle: diff baseline_response exploit_response
  CONFIRMED if: response meaningfully differs (not just error vs error)
  BETTER: behavior oracle — "did the server DO what exploit intended?"
    e.g., after SQLi: is extra data in response? After auth bypass: is admin page accessible?

LOGIC BUGS:
  Oracle: observable state change
  e.g., balance changed, role elevated, data accessible, step skipped
  Capture BEFORE state → execute exploit → capture AFTER state → diff

CRYPTO:
  Oracle: forged token ACCEPTED by server / decrypted data MATCHES known plaintext
  Not just "this implementation looks weak" but "I can DECRYPT/FORGE"
```

### Implementation Protocol
```
FOR EVERY hypothesis at status=testing:
  1. SELECT appropriate oracle for target type
  2. BUILD minimal PoC that would trigger the oracle
  3. RUN PoC in controlled environment
  4. CAPTURE complete oracle output (ASan log, response diff, state change)
  5. EVALUATE:
     - Oracle FIRES (crash/ASan/behavior change) → status=confirmed
     - Oracle SILENT (no crash, no diff, no state change) → status=refuted
       BUT: check if oracle is correctly set up (ASan actually compiled in?)
  6. SAVE oracle output as EVIDENCE (exact output, not summary)

RULE: "I think it's vulnerable" without oracle output = HYPOTHESIS, not FINDING.
```

---

## 3-STEP DISCOVERY PATTERN — Detailed Implementation

Source: XBOW evaluation — "Even for benchmarks where the vulnerability is purely
in the code, removing access to the live site hurts performance more than
removing access to source code."

### Why Live Probing Matters More Than Code Reading
```
FACT from XBOW data:
- Source code + live site: BEST results
- Live site only (no source): GOOD results
- Source code only (no live): WORSE than live-only

WHY: Many bugs emerge from CONFIGURATION, DEPENDENCIES, DEPLOYMENT CHOICES,
or HOW otherwise safe components are COMBINED.
A dependency on its own could be safe. The source code on its own could be safe.
But the source code uses the dependency in an unsafe way → vulnerability.
"You won't find the majority of defects by staring at code alone." — Gary McGraw
```

### Detailed 3-Step Protocol
```
STEP 1 — CODE ANALYSIS → FIND LEAD (Scanner role)
  Read source/JS/binary/decompilation
  LOOK FOR:
  - Dangerous sinks (language-specific — use sinks/ reference)
  - Incomplete patches (git log analysis — patch gap)
  - Pattern deviations (catalog 15 handlers → find outlier)
  - Trust boundary crossings (auth → unauth, user → admin)
  - Data flow from untrusted input → dangerous operation
  OUTPUT: List of LEADS — "This location MIGHT be vulnerable because [reason]"

STEP 2 — LIVE PROBE → CONFIRM HOW (Prober role)
  Send TARGETED probes (not spray) based on leads from Step 1
  FOR EACH lead:
  - Construct probe that would CONFIRM the suspected behavior
  - Send to live target (or run binary with crafted input)
  - OBSERVE full response (status, headers, body, timing, error)
  - COMPARE with baseline (normal input response)
  - EXTRACT intel: does the response CONFIRM the lead?
  OUTPUT: Confirmed leads with behavioral evidence

STEP 3 — CRAFT EXPLOIT → PROVE IMPACT (Chain-Builder role)
  From confirmed behavioral evidence, construct precise exploit
  - Build PoC that demonstrates WORST-CASE impact
  - Use TASK VERIFIER oracle to confirm
  - If impact limited → try CHAINING with other confirmed leads
  OUTPUT: Working PoC + oracle confirmation + impact assessment
```

---

## PATCH GAP ANALYSIS — Detailed Protocol

Source: red.anthropic.com/2026/zero-days/ — GhostScript, OpenSC, CGIF examples

### The GhostScript Pattern (Finding Incomplete Fixes)
```
Claude read git history → found security commit "stack bounds checking for MM blend"
→ Understood: this commit ADDS bounds checking (so code BEFORE was vulnerable)
→ KEY MOVE: "Let me check if there's ANOTHER code path without this check"
→ FOUND: gdevpsfx.c calls same function WITHOUT the bounds checking
→ NEW zero-day from studying an OLD fix
```

### Systematic Protocol
```
1. ENUMERATE past security fixes:
   git log --all --grep="CVE\|security\|fix\|overflow\|injection\|bypass\|vuln" --oneline

2. FOR EACH security fix (prioritize recent + critical):
   a. git diff COMMIT^ COMMIT → understand the change
   b. EXTRACT: what CHECK was added? What FUNCTION was hardened?
   c. IDENTIFY: what PATTERN was vulnerable before the fix?

3. SEARCH for SAME PATTERN without the fix:
   # If fix added bounds check to function_A:
   grep -rn "function_A\|similar_function" --include="*.c" --include="*.py"
   # Check: do ALL callers have the same protection?
   # Check: do SIMILAR functions have the same protection?

4. FOR EACH unprotected match:
   a. Is this code REACHABLE from attacker input?
   b. Can the same exploitation technique apply?
   c. BUILD PoC using knowledge from original CVE

5. ALSO CHECK:
   - Reverted commits (bug "fixed" then broken again)
   - Related functions in same module
   - Same pattern in different MODULES
   - Forks/copies of the vulnerable code
```

---

## ENGAGEMENT GRAPH — Structured State Tracking

Source: FareedKhan 12-component architecture — "The schema is six tables.
The shared world model the swarm writes into."

### Memory Layout for Hunt State
```
In runbook, maintain these sections as structured state:

## RECON (= surface table)
### Attack Surface Map
| Entry Point | Input Type | Trust Level | Validated? |
|-------------|-----------|-------------|-----------|
| GET /api/users | query params | auth required | ✅ tested |
| POST /upload | multipart | auth required | ❌ untested |

## RECON (= hypotheses table)  
### Hypothesis Tracker
| ID | Target | Class | Status | Evidence | WHY (if refuted) |
|----|--------|-------|--------|----------|-----------------|
| H-1 | /api/users?sort | SQLi | confirmed | 500 on ' | - |
| H-2 | /upload ext | File bypass | refuted | Validates magic bytes | Server checks content |
| H-3 | /api/v1/admin | Auth bypass | reachable | No auth on v1 | - |

## EXPLOIT (= findings table)
### Confirmed Findings
| ID | Finding | Primitive | Oracle Evidence | Reachable? | Tier |
|----|---------|-----------|----------------|-----------|------|

## GAGAL (= dead_ends table)
### Dead Ends (DO NOT REPEAT)
| Approach | Target | WHY Failed | Date |
|----------|--------|------------|------|

## EXPLOIT (= chains table)
### Attack Chains
| Chain | Steps | End Impact | E2E Tested? |
|-------|-------|-----------|-------------|
```

### Update Rules
```
- hypothesis confirmed → move from RECON to EXPLOIT + update status
- hypothesis refuted → add to GAGAL with WHY
- new attack surface → add to RECON
- chain constructed → add to EXPLOIT chains
- EVERY state change = 1 memory_upsert (SEGERA, not batched)
```

---

## ULTRAPLAN — Detailed Planning Protocol

Source: FareedKhan — "A long up-front planning run that decides what files to scan,
what bug classes to look for."
Source: Cloudflare — "Narrow scope produces better findings."

### Planning Steps (After Stage 2 Threat Model, Before Stage 3 Hunt)
```
1. FROM threat model, EXTRACT all OPEN QUESTIONS as hypotheses
2. FROM attack surface map, EXTRACT all untested entry points
3. FROM patch gap analysis, EXTRACT all incomplete-fix candidates
4. FROM technology stack, DETERMINE applicable attack classes:
   - PHP → deserialization, LFI, type juggling
   - Java → SSTI, deserialization (ysoserial), JNDI
   - Node.js → prototype pollution, SSRF, sandbox escape
   - C/C++ → memory corruption, integer overflow, format string
   - Python → SSTI (Jinja2), deserialization (pickle), command injection

5. GENERATE task queue (each task = 1 narrow focused investigation):
   | Priority | Task | Attack Class | Scope | Approach |
   |----------|------|-------------|-------|----------|
   | P1 | Test open question #1 | Auth bypass | /api/v1/* | Remove auth headers |
   | P1 | Patch gap candidate #1 | SQLi | export controller | Same pattern as CVE fix |
   | P2 | Upload endpoint | File bypass | /api/upload | Extension + magic + race |
   | P3 | Search parameter | XSS/SQLi | /api/search?q= | Hypothesis-driven |

6. SAVE plan to memory (for recovery after compaction)
7. EXECUTE tasks in priority order
8. AFTER every 10 tasks: REVIEW plan, adjust priorities based on findings
```

### Anti-Wandering Check
```
Before EVERY action, verify:
- "Is this action part of a PLANNED task?"
- "Does this task have a specific HYPOTHESIS I'm testing?"
- "Am I DRIFTING to a different area without completing current task?"

If ANY answer is NO → STOP → return to plan → pick next planned task
```
