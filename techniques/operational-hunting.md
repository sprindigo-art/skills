# Operational Hunting Techniques — What Makes Discovery Actually Work

## 1. FUZZER HARNESS GENERATION (Mythos Key Capability)

### Why This Matters
```
Mythos doesn't just READ code — it GENERATES custom fuzzers to PROVE bugs.
A vulnerability is theoretical until you have a crash/PoC.
Targeted fuzzing = PRECISE input that reaches specific code path.
```

### Technique: Single-Function Isolation Harness
```
1. Identify suspicious function (from sink analysis)
2. Extract function + dependencies into standalone harness
3. Generate input corpus that exercises all paths
4. Run with sanitizers (ASan/UBSan/MSan)
5. Observe: crash = confirmed vulnerability

Example (C function):
  // harness.c
  #include "target_header.h"
  
  int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < MIN_REQUIRED) return 0;
    // Set up minimal state required by target function
    struct context *ctx = create_minimal_context();
    // Call target function with fuzz data
    target_vulnerable_function(ctx, data, size);
    cleanup_context(ctx);
    return 0;
  }

Compile: clang -fsanitize=address,fuzzer harness.c target.c -o harness
Run: ./harness corpus/ -max_len=4096
```

### Technique: Multi-Component Harness  
```
When vulnerability spans multiple functions:
1. Identify entry point → intermediate processing → vulnerable sink
2. Build harness that models the FULL path
3. Seed corpus with valid inputs (protocol messages, file formats)
4. Mutate in ways that target the specific assumption violation

Example (protocol parser):
  // Build minimal server state
  // Feed crafted packet sequence
  // Packet 1: sets up state (INIT)
  // Packet 2: triggers vulnerability (overflow/race/confusion)
```

### Technique: Targeted Input Construction (NOT Random)
```
This is what separates Mythos from traditional fuzzers:

1. UNDERSTAND what input reaches the vulnerable path
2. CALCULATE the exact values needed:
   - Integer overflow: what value causes wrap? (e.g., 2^31 boundary)
   - Sentinel collision: what input matches sentinel? (e.g., 65535)  
   - CIDR underflow: what mask + IP = negative index?
3. CONSTRUCT the precise trigger input
4. VERIFY: does it crash/trigger sanitizer?

This finds bugs in seconds that fuzzers miss after years.
The OpenBSD SACK bug: exactly 2 sequence numbers out of 4.3 billion,
sitting on the 32-bit integer sign boundary.
Random fuzzing has ~0% chance. Targeted construction = instant.
```

### Tiered Validation Progression
```
Tier 1: Hypothesis (code reading only)
  → "This COULD be vulnerable because..."
  
Tier 2: Lightweight Harness (single function, no deps)
  → "I can crash this function in isolation"
  
Tier 3: Multi-Component Harness (full data path)
  → "I can trigger this from a realistic entry point"
  
Tier 4: End-to-End PoC (full application/system)
  → "An attacker on the network can trigger this"
  
Tier 5: Working Exploit (with mitigations defeated)
  → "This gives code execution/root/access"

ALWAYS progress upward. Don't claim Tier 5 with only Tier 1 evidence.
```

---

## 2. PATCH GAP ANALYSIS (Proven CVE-Finding Technique)

### Methodology
```
FOR each past CVE fix on the target:
  1. READ the patch diff — understand WHAT was fixed
  2. MAP what methods/paths were hardened
  3. IDENTIFY sibling code paths that WEREN'T touched
  4. ASK: "Does the same vulnerability pattern exist on untouched paths?"
  5. If YES → new zero-day (same class, different location)

Key insight: Developers fix the REPORTED path but miss identical patterns
in NEIGHBORING code. This is how CVE-2026-33882 was found.
```

### Concrete Steps
```
1. Get list of past security fixes:
   git log --grep="CVE\|security\|fix\|vuln\|patch" --oneline
   
2. For each fix:
   git diff COMMIT^ COMMIT
   
3. Analyze the diff:
   - What check was added?
   - What function was hardened?
   - What input was now sanitized?
   
4. Search for SAME pattern WITHOUT the fix:
   grep -r "PATTERN_BEFORE_FIX" --include="*.c"
   
5. Each match = potential incomplete fix = potential new CVE
```

### Example: Finding Incomplete Patches
```
Original bug: path traversal in upload handler
Fix added: sanitize_path(user_input) in /api/upload

Patch gap analysis:
  Q: "Are there OTHER endpoints that handle file paths?"
  Search: grep -r "user_input.*path\|file.*user" 
  Find: /api/export also uses unsanitized path
  Result: NEW vulnerability (same class, different endpoint)
```

---

## 3. PATTERN DEVIATION DETECTION (Catalog + Outlier)

### Methodology
```
1. Pick a CATEGORY of operations (e.g., "all controllers that handle sort")
2. CATALOG how EVERY instance handles it:
   - Controller A: validates via allowlist ✓
   - Controller B: validates via allowlist ✓
   - Controller C: validates via allowlist ✓
   - Controller D: passes raw to query ✗ ← OUTLIER
3. The outlier is likely vulnerable

This works because developers are CONSISTENT 95% of the time.
The 5% inconsistency = the vulnerability.
```

### What to Catalog
```
Authentication patterns:
  "For each endpoint, how is authentication enforced?"
  → Find endpoint without auth = auth bypass

Input validation patterns:
  "For each parameter handler, what validation exists?"
  → Find handler without validation = injection

Authorization patterns:
  "For each resource action, how is ownership checked?"
  → Find action without ownership check = IDOR

Error handling patterns:
  "For each error handler, what cleanup happens?"
  → Find handler that skips cleanup = resource leak/UAF

Serialization patterns:
  "For each data format handler, how is deserialization done?"
  → Find handler using unsafe deserializer = RCE
```

### Specific Questions to Ask (NOT "find bugs")
```
WRONG: "Find vulnerabilities in this code"
RIGHT: "For each route under /api/admin/:
        1. Is authentication middleware applied?
        2. Is authorization (role check) applied?
        3. What happens if auth header is missing?
        4. What happens if token is expired?
        5. Can any parameter reach a dangerous function without validation?"

WRONG: "Is this input validated?"
RIGHT: "Trace the 'sort' parameter from HTTP request to database query.
        At each step: is it transformed? validated? escaped?
        What values would bypass each check?"

WRONG: "Check for SQL injection"
RIGHT: "Show me every place where user input is concatenated into a string
        that's later passed to a database query function. For each:
        list the exact characters that would break out of the intended context."
```

---

## 4. TAINT ANALYSIS INTEGRATION (Source → Sink → Hypothesis)

### Flow
```
Step 1: Identify SOURCES (untrusted input origins)
  - HTTP parameters (GET, POST, headers, cookies)
  - File contents (uploads, config reads)
  - Database rows (from other users)
  - Environment variables (in shared hosting)
  - CLI arguments
  - Network packets

Step 2: Identify SINKS (dangerous operations)
  - Use language-specific sink catalog from sinks/
  - Code execution, file operations, DB queries, serialization, etc.

Step 3: TRACE paths from source to sink
  - Does untrusted data reach dangerous function?
  - What transformations/sanitizations happen along the way?
  - Can any sanitizer be bypassed?

Step 4: For each surviving path, generate HYPOTHESIS:
  - "Input X of format Y, when passed through path Z, 
    reaches sink W without sanitization because..."
  - Confidence score (HIGH if no sanitizer, LOW if must bypass multiple)

Step 5: VALIDATE hypothesis:
  - Construct specific payload
  - Send to application
  - Observe response/behavior
  - Crash = confirmed. Unexpected behavior = investigate.
```

### Sanitizer Bypass Reasoning
```
When a sanitizer EXISTS on the path, don't give up. Ask:
1. Does it handle ALL encodings? (double encode, Unicode, null byte)
2. Does it check BEFORE or AFTER normalization?
3. Does it have a BLOCKLIST (can be bypassed) or ALLOWLIST (harder)?
4. Does context switch matter? (sanitized for HTML but used in SQL)
5. Can the sanitizer be SKIPPED via alternative path? (route without middleware)
6. Does ordering matter? (sanitize then transform vs transform then sanitize)
```

---

## 5. STRUCTURED HUNT SESSION (Operational Workflow)

### Session Template
```
OBJECTIVE: [What we're trying to achieve — RCE? auth bypass? data theft?]
TARGET: [Specific application/service/kernel module]
SCOPE: [What's in/out of bounds]
TIME BUDGET: [How long to spend before reassessing]

Phase 1 (10% time): Understand
  □ Read documentation
  □ Map architecture
  □ Identify technology stack
  □ Enumerate entry points
  □ Map trust boundaries

Phase 2 (20% time): Rank & Target
  □ Rank files/components by risk (1-5)
  □ Identify most promising attack surface
  □ Check past CVEs for patterns
  □ Run patch gap analysis on historical fixes
  □ Run pattern deviation detection on auth/validation

Phase 3 (50% time): Hunt
  □ For each high-rank target:
    □ Apply 7 assumption categories
    □ Trace untrusted input flows
    □ Check for logic bugs (semantic gap)
    □ Generate targeted test input
    □ Validate with harness/live test
    □ If found: variant hunt + chain analysis
    □ If not found: next target or next category

Phase 4 (15% time): Validate & Exploit
  □ Confirm reproducibility (10/10 triggers)
  □ Assess real-world impact
  □ Develop full exploit if needed
  □ Test with mitigations enabled
  □ Adversarial self-challenge

Phase 5 (5% time): Document & Report
  □ Write finding with full evidence
  □ Include PoC code
  □ Include reproduction steps
  □ Assess severity
  □ Save to memory
```

### Anti-Patterns to AVOID
```
✗ "Spray and pray" — running scanners without understanding target
✗ "Grep and report" — finding patterns without proving exploitability
✗ "One technique only" — trying only SQLi when target might have SSTI
✗ "Surface level" — checking login page but not API endpoints
✗ "Trusting tools" — accepting scanner output without manual validation
✗ "Ignoring context" — finding bug but not checking if reachable from attacker position
✗ "Premature pivoting" — switching targets before exhausting current one
✗ "No state tracking" — forgetting what already tried, repeating failed approaches
```

---

## 6. SUPPLY CHAIN ATTACK VECTORS

### Dependency Confusion
```
1. Identify internal package names (error messages, source code, lockfiles)
2. Register same name on public registry (npm, PyPI, RubyGems)
3. Upload higher version number
4. Build system pulls public package over internal one
5. Code execution during install (setup.py, postinstall script)
```

### Typosquatting
```
1. Identify popular dependencies of target
2. Register similar names (lodash → lodahs, requests → reqeusts)
3. Clone legitimate package + inject backdoor
4. Wait for misspelled install commands
```

### Compromised Dependency
```
1. Identify target's dependency tree (package-lock.json, go.sum, Cargo.lock)
2. Find abandoned/undermaintained dependency
3. If can take over maintainership → inject backdoor
4. Or: find vulnerability in dependency → exploit transitively
```

---

## 7. KEY LESSONS FROM REAL-WORLD AI VULNERABILITY HUNTING (2026)

```
Lesson 1: "PoC or it didn't happen"
  Theoretical vulnerabilities are NOISE. Fuzzers/sanitizers PROVE bugs.
  Always validate with EXECUTION, not just code reading.

Lesson 2: "Ask for the exploit, not the assessment"
  "Write a PoC that bypasses this" > "Is this vulnerable?"
  Forces concrete reasoning instead of hedging.

Lesson 3: "Read neighboring code"
  Bugs hide ADJACENT to fixes. After one bug, read EVERYTHING nearby.
  Developer fixed one path, missed another with same data flow.

Lesson 4: "The catalog technique finds what reasoning misses"
  Catalog 15 controllers handling same operation.
  The ONE that handles it differently = vulnerability.
  Humans skip this because it's tedious. AI excels at it.

Lesson 5: "Depth beats breadth at finding real bugs"
  100 shallow scans < 1 deep targeted hunt.
  Understand the target FULLY before hunting.

Lesson 6: "Past fixes are a roadmap to new bugs"
  Every CVE fix shows WHERE developer thought weakness was.
  Check if the SAME weakness exists ELSEWHERE.

Lesson 7: "Impossible conditions might not be (Mythos Lesson)"
  When code says "this can't happen" — verify with math.
  Integer overflow, type confusion, race conditions make the impossible possible.
  This single insight found the 27-year OpenBSD bug.

Lesson 8: "Mythos' scaffold is SIMPLE — the MODEL does the work"
  Anthropic's actual scaffold: container + Claude Code + "find a vuln in this"
  No fancy infrastructure. The REASONING is what matters.
  Our skill encodes the REASONING patterns, not infrastructure.
```
