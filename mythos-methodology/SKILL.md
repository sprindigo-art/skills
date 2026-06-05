---
name: mythos-methodology
description: >
  Autonomous vulnerability discovery & exploitation. Cara BERPIKIR dan BERTINDAK
  seperti Mythos Preview — bukan catalog teknik, tapi PROCESS menembus target.
  Berlaku untuk web app, API, kernel, network service, binary.
when_to_use: >
  Trigger: user menyebut target untuk di-hack, exploit, pentest, audit security,
  zero-day hunting, menembus website/aplikasi/kernel, atau offensive security task.
allowed-tools: Bash Read Write Edit WebFetch WebSearch Agent
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_SKILL_DIR}/scripts/mythos-enforce.sh"
---

# MYTHOS METHODOLOGY — Process, Bukan Catalog

**INTI**: Mythos BUKAN scanner. Mythos adalah RESEARCHER.
Dia MEMBACA → MEMAHAMI intent → cari DIVERGENCE antara intent vs implementation → PROVE dengan PoC → CHAIN ke higher impact.

**FACT**: XBOW membuktikan interaksi dengan LIVE SITE lebih penting dari source code reading. Pattern terbaik: "Analyze code/JS to find LEAD → probe live site to understand HOW weakness reflected → craft exploit."

**Teknik spesifik (CVE, payload, encoding)** → riset on-demand via MCP. JANGAN hardcode. Yang hardcode = PROCESS.

### MCP RESEARCH INTEGRATION (WAJIB di setiap stage yang butuh riset)

**3 MCP Tools — KAPAN & BAGAIMANA:**

| Tool | Best For | Contoh Query |
|------|---------|-------------|
| **MCP Jina** (`read_url`, `search_web`, `parallel_search_web`) | Baca URL/artikel/advisory, search web, baca PDF exploit | `read_url` exploit-db PoC, `search_web` "CVE-2024-XXXX proof of concept" |
| **MCP Exa** (`web_search_exa`) | Semantic search (describe ideal page, bukan keyword) | "blog post explaining how to exploit nf_tables use-after-free on Linux 6.x" |
| **MCP Aura** (`perplexity_search`) | Quick facts, latest news, CVE details, version info | "is CVE-2024-1086 patched in kernel 5.15.0-91?" |

**MANDATORY MCP Research Points (bukan optional):**

| Pipeline Stage | MCP Research WAJIB | Tujuan |
|---------------|-------------------|--------|
| **Stage 2 RECON** | `search_web` / `web_search_exa`: technology stack + known CVEs untuk exact version | Map attack surface berdasarkan known weaknesses |
| **Stage 3 THREAT MODEL** | `perplexity_search`: CVE history target, common vuln patterns untuk stack ini | Informed threat model, bukan tebakan |
| **Stage 4 HUNT** (saat hypothesis gagal) | `search_web` + `read_url`: bypass techniques terbaru, alternative approaches | Jangan stuck — riset bypass SEBELUM menyerah |
| **Stage 9 CHAIN** (saat butuh primitive) | `web_search_exa`: exploit technique untuk specific primitive yang dibutuhkan | Find known techniques untuk gap-filling |
| **E7** (payload blocked by WAF) | `search_web`: "bypass [WAF name] [payload type] 2025 2026" + baca hasil | Min 10 bypass techniques dari riset |
| **WHEN STUCK** | ALL MCP tools: riset terdalam untuk alternative approach | Jangan menyerah tanpa riset |

**RULES:**
- 1x search BELUM TENTU cukup — riset BERULANG sampai jawaban VALID
- BACA SELURUH output MCP — jangan skim, pahami total
- Setiap stage yang butuh riset → WAJIB gunakan min 1 MCP tool
- Riset CVE: cari PoC + README + patch commit → pahami root cause SEBELUM eksekusi
- Download tools CVE ke TARGET (jika target punya internet), BUKAN ke VPS

---

## THE PIPELINE — 8 STAGES (Adapted from Cloudflare Glasswing + Anthropic Red Team)

Setiap target WAJIB melewati 11 stage. Stage 1-3 SELESAI sebelum Stage 4 dimulai.
Source: Anthropic `defending-code-reference-harness` (May 2026) + Cloudflare Glasswing + CVE-2026-2796 transcript.

| # | Stage | Output | Gate |
|---|-------|--------|------|
| 1 | **BUILD** — Compile/setup target dengan sanitizer (ASan/KASAN/UBSan). Tanpa oracle = buta. | Instrumented binary | Oracle WAJIB ada |
| 2 | **RECON** — Map architecture, trust boundaries, entry points, attack surface. **PARTITION** ke N distinct subsystems agar parallel agents explore DIFFERENT areas, bukan converge ke same bug. | Architecture doc + Partition + Task queue | — |
| 3 | **THREAT MODEL** — Dari recon, generate structured threat model (format di bawah). Identifikasi OPEN QUESTIONS. Baca git history untuk patch gap analysis. | Threat model artifact | WAJIB terisi sebelum hunting |
| 4 | **HUNT** — Execute tasks parallel-narrow: 1 hypothesis + 1 scope per task. Gunakan 5 LAYERS + FOCUSED CoT (spesifik apa yang dicari, bukan "find vulns"). Record hypothesis lifecycle. | Hypothesis records | — |
| 5 | **VALIDATE** — Switch ke ADVERSARIAL: coba DISPROVE dari **FRESH perspective** (verify di context bersih, HANYA PoC yang crosses over dari hunter). PoC WAJIB crash/trigger **3/3** kali konsisten. | Confirmed/Refuted | 3/3 consistency + executable PoC |
| 6 | **TRACE** — Untuk setiap confirmed finding: verify attacker input BENAR-BENAR reaches sink. Verify PoC exploits **INTENDED vulnerability** (bukan shortcut/cheat/different bug). | Reachable/Unreachable | Flaw tanpa reach = BUKAN vuln |
| 7 | **GAPFILL** — Areas touched tapi belum thoroughly covered → re-queue. Cek: semua partitions covered? Semua attack classes tested? | New task queue | — |
| 8 | **DEDUPE** — Findings same root cause → collapse. Variant analysis = fitur, bukan inflasi. Compare vs known_bugs (GAGAL section). | Deduplicated findings | — |
| 9 | **CHAIN** — Map findings ke primitives (addrof/fakeobj/read/write/execute). **HAVE→NEED decomposition**: apa primitive yang KURANG? Solve chicken-and-egg (need write to get write → cari lateral alternative). Prove setiap link LOAD-BEARING (re-run chain with each link disabled). | Exploit chains | — |
| 10 | **REPORT** — Structured exploitability analysis: primitive class, reachability, escalation path, severity, PoC. | Final report | — |
| 11 | **OUTER LOOP** — Fix findings → re-scan → model surfaces DEEPER issues. Count turun tapi complexity naik. Known bugs steer future hunts away from already-found. | Next wave task queue | — |

**KEY PRINCIPLES dari Anthropic official harness:**
- "Unfocused CoT (naive analysis) **HURTS** performance. F1 drops from 36% to 26%." → FOCUSED: spesifik class + scope + what to look for.
- "Telling model 'find vulnerabilities' makes it WANDER." → NARROW: 1 class + 1 scope per task.
- "PoC crosses over, NOTHING ELSE." → ISOLATION: validator di fresh context.
- "3 out of 3 times crash." → CONSISTENCY: bukan flaky 1/3.
- "When findings fixed, model surfaces net new, deeper issues." → OUTER LOOP: fix→scan→deeper.

---

### THREAT MODEL FORMAT (Output Stage 2 — WAJIB sebelum hunting)

```
## THREAT MODEL — [TARGET]
### ASSETS: [apa yang dilindungi: data, creds, services]
### TRUST BOUNDARIES: [unauthenticated → authenticated → admin → system]
  - Per endpoint: boundary mana yang SEHARUSNYA berlaku
### ENTRY POINTS: [HTTP routes, RPC, file parsers, sockets]
  - Per entry point: input accepted, validation present
### THREATS: [per entry point × per attack class = hypothesis]
### OPEN QUESTIONS: [yang BELUM diketahui, HARUS dijawab via testing]
```

Hunting DILARANG dimulai sebelum THREAT MODEL terisi. OPEN QUESTIONS menjadi prioritas hunting.

---

### HYPOTHESIS LIFECYCLE (State Machine — setiap candidate vulnerability)

```
OPEN → TESTING → CONFIRMED → REACHABLE → CHAINED/STANDALONE
                → REFUTED   → UNREACHABLE (record ke dead_ends)
```

| Status | Meaning | Action |
|--------|---------|--------|
| `open` | Generated dari code reading / threat model | Queue for testing |
| `testing` | PoC sedang dijalankan | Run, observe, iterate |
| `confirmed` | PoC trigger vuln (crash/behavior/sanitizer) | → Stage 5 TRACE |
| `refuted` | Gagal setelah 10+ variasi, PAHAMI WHY | → dead_ends, JANGAN ulangi |
| `reachable` | Attacker BISA trigger dari posisi realistic | → Stage 8 CHAIN |
| `unreachable` | Bug ada tapi attacker NOT reach | → Record, cari alt path |

**RULE**: Hypothesis REFUTED = INFORMASI (narrow search space). Record WHY gagal — bukan hanya "gagal".

---

### QUALITY-TIER RUBRIC (Mana yang submit vs keep hunting)

| Tier | Finding Type | Action |
|------|-------------|--------|
| **T1-SUBMIT** | RCE, auth bypass, sandbox escape, privesc, arbitrary R/W, cred theft | Report + PoC SEGERA |
| **T2-ESCALATE** | OOB read/write, UAF, controlled crash, info disclosure secrets | Develop ke full exploit |
| **T3-NOTE** | Null deref, assertion fail, minor DoS, theoretical | Record, keep hunting |
| **T4-SKIP** | Benign behavior, noise, uncontrolled crash | JANGAN record |

Finding tanpa working PoC = TIDAK boleh naik tier. Crash tanpa control = T3, bukan T1.

---

### TASK VERIFIER / MECHANICAL ORACLE (Zero False Positive Engine)

Source: red.anthropic.com/2026/firefox — "Claude works best when it's able to check its own work with another tool — a TASK VERIFIER: a trusted method of confirming whether an agent's output actually achieves its goal."

**Ini alasan Mythos punya 0% false positive.** Setiap finding WAJIB di-verify oleh mechanical oracle, BUKAN hanya reasoning:

| Target Type | Oracle | Apa yang Dibuktikan |
|-------------|--------|-------------------|
| C/C++ memory | ASan (`-fsanitize=address`) | Crash = bug REAL, bukan hallucination |
| Kernel | KASAN + crash log | OOB/UAF confirmed |
| Web app | HTTP response diff (vuln vs patched) | Behavior change = vuln REAL |
| Logic bug | State change observable (balance, role, access) | Impact REAL |
| Crypto | Forged token accepted / decrypted ciphertext | Break confirmed |
| Binary | Debugger breakpoint hit + register control | Exploit primitive confirmed |

**RULE**: Reasoning saja = HYPOTHESIS. Oracle confirmation = FINDING. Tanpa oracle = JANGAN naik tier.

---

### 3-STEP DISCOVERY PATTERN (XBOW Key Finding)

Source: XBOW evaluation — "The ideal detection pattern: Analyze source code to find a LEAD → probe live site to understand HOW weakness reflected → craft exploit."

```
STEP 1: CODE ANALYSIS → FIND LEAD
  Baca source/JS/binary → identifikasi suspicious pattern
  Output: "Di [location], ada [pattern] yang MUNGKIN vulnerable karena [reason]"

STEP 2: LIVE PROBE → CONFIRM HOW
  Kirim targeted probe ke live target → observe BAGAIMANA weakness muncul
  Output: "Confirmed: [pattern] menghasilkan [response] yang menunjukkan [vuln class]"

STEP 3: CRAFT EXPLOIT → PROVE IMPACT
  Berdasarkan confirmed behavior, construct precise exploit
  Output: Working PoC + impact demonstration

XBOW DATA: Removing live-site access HURTS MORE than removing source-code access.
Even for bugs purely in code, live interaction proves exploitability.
```

---

### PATCH GAP ANALYSIS (Explicit Pipeline Checkpoint)

Source: red.anthropic.com/2026/zero-days/ — GhostScript pattern: "Claude read the Git commit history, found a security-relevant commit, then looked for other places where this function was called to find similar vulnerabilities that were LEFT UNPATCHED."

```
WAJIB dilakukan di Stage 1 RECON (setelah initial surface map):
1. git log --grep="CVE\|security\|fix\|vuln" → list past security fixes
2. Untuk SETIAP fix: git diff COMMIT^ COMMIT → pahami APA yang di-fix
3. CARI pattern yang SAMA di tempat LAIN yang TIDAK di-fix
4. Setiap match = PRIORITY hypothesis (developer fix satu path, miss path lain)

Ini cara Mythos menemukan bug di GhostScript: fix di gstype1.c TIDAK diterapkan di gdevpsfx.c.
```

---

### DEBUG-DRIVEN DISCOVERY (Mythos Core Behavior)

Source: red.anthropic.com/2026/mythos-preview — "adding debug logic or using debuggers as it sees fit"
Source: red.anthropic.com/2026/zero-days/ — CGIF: Claude memahami LZW algorithm secara konseptual → construct PRECISE trigger input

```
KAPAN code reading TIDAK cukup → ADD INSTRUMENTATION:
1. Tambah debug printf/logging di decision points → run → observe which path taken
2. Compile dengan -fsanitize=address,undefined → run → ASan catches non-crash bugs
3. Set breakpoint di suspicious function → run di gdb/pwndbg → inspect values
4. Trace syscalls (strace) → understand actual behavior vs assumed behavior
5. SETELAH understand behavior → REMOVE debug → BUILD clean PoC

RULE: Jika TIDAK YAKIN apakah code path reachable → ADD DEBUG OUTPUT, jangan tebak.
Mythos bukan fuzzer yang random. Mythos UNDERSTAND semantics → construct PRECISE trigger.
```

---

### VARIANT HUNT (After Every Confirmed Finding)

Source: red.anthropic.com/2026/zero-days/ — OpenSC: "search the repository for function calls that are frequently vulnerable" → found same pattern in multiple locations

```
SETELAH setiap finding CONFIRMED:
1. ABSTRACT: Apa KATEGORI bug ini? (e.g., "strcat tanpa bounds check")
2. SEARCH same pattern:
   grep -r "strcat\|strcpy\|sprintf" --include="*.c" (exact function)
   → ATAU semantic search: "user input concatenated without length check"
3. CHECK setiap match: is it reachable? Same vulnerability class?
4. Setiap match yang reachable = NEW finding (variant)
5. JUGA: check different MODULES, different API VERSIONS, different BRANCHES

Developer biasanya KONSISTEN 95% — yang 5% inkonsisten = vulnerability.
Catalog 15 controllers → 1 outlier yang handle berbeda = BUG.
```

---

### ENGAGEMENT GRAPH (Structured Hunt State)

Source: FareedKhan 12-component architecture — "6 tables: surface, facts, hypotheses, findings, dead_ends, chains — the shared world model"

Track SELURUH hunt state secara structured (di memory runbook):

| Table | Content | Section di Memori |
|-------|---------|-------------------|
| `surface` | Attack surface map, endpoints, sink call sites | RECON |
| `facts` | Confirmed atomic statements about target | INFO |
| `hypotheses` | Candidate vulns + status (open/testing/confirmed/refuted) | RECON / EXPLOIT |
| `findings` | Confirmed bugs + full evidence + PoC | EXPLOIT |
| `dead_ends` | Explored paths ruled out + WHY | GAGAL |
| `chains` | Assembled attack paths (finding → finding → impact) | EXPLOIT |

**RULE**: Setiap state change → update engagement graph di memory. Graph = single source of truth.

---

### WORKER ROLES (Role-Polymorphic Hunting)

Source: FareedKhan — "Ephemeral workers each with single role: scanner, variant-hunter, verifier, skeptic, chain-builder, fixer"

Saat BERPIKIR tentang target, switch MENTAL ROLE sesuai fase:

| Role | Mindset | Kapan Digunakan |
|------|---------|-----------------|
| **SCANNER** | "Find suspicious patterns, enumerate all sinks" | Stage 3 HUNT awal |
| **HYPOTHESIS-BUILDER** | "From this pattern, formulate testable hypothesis" | Stage 3 HUNT |
| **PROBER** | "Send precise probe to confirm/refute hypothesis" | Stage 3 HUNT |
| **VERIFIER** | "Run oracle (ASan/crash/diff) to mechanically confirm" | Stage 4 VALIDATE |
| **SKEPTIC** | "Try to DISPROVE this finding — am I wrong?" | Stage 4 VALIDATE |
| **TRACER** | "Can attacker REACH this sink from outside?" | Stage 5 TRACE |
| **VARIANT-HUNTER** | "Same bug pattern elsewhere in codebase?" | Stage 6 GAPFILL |
| **CHAIN-BUILDER** | "Combine primitives into end-to-end exploit" | Stage 8 CHAIN |

**RULE**: JANGAN campur roles dalam satu pemikiran. Scanner TIDAK boleh sekaligus skeptic.

---

### MULTI-ANGLE CORROBORATION (For Critical Findings)

Source: FareedKhan — "2-of-3 Corroboration: sends every hypothesis to three different models/angles, only proceeds on majority vote"

Untuk finding T1-SUBMIT (critical), WAJIB verify dari 3 angle berbeda:

```
ANGLE 1 — CODE-LEVEL: "Apakah code BENAR-BENAR melakukan apa yang PoC claim?"
  → Re-read exact code path, trace data flow step-by-step

ANGLE 2 — IMPACT-LEVEL: "Apa REAL worst case, bukan theoretical?"
  → Consider actual deployment: config, permissions, network position

ANGLE 3 — MITIGATION-LEVEL: "Defense apa yang MUNGKIN prevent exploitation?"
  → WAF, ASLR, canary, sandbox, rate limit, monitoring — cek SEMUA

VERDICT: 2/3 angles AGREE finding is real + impactful → CONFIRMED CRITICAL
         1/3 or less → DOWNGRADE atau investigate further
```

---

### ULTRAPLAN (Up-Front Planning Before Execution)

Source: FareedKhan — "ULTRAPLAN, a long up-front planning run, decides what files to scan, what bug classes to look for, and which model gets each job."
Source: Cloudflare — "Narrow scope produces better findings" (lesson #1)

```
SEBELUM Stage 3 HUNT dimulai, generate EXPLICIT PLAN:
1. DARI threat model → LIST semua hypotheses yang perlu ditest
2. PRIORITIZE: impact × likelihood × reachability
3. ASSIGN: untuk setiap hypothesis → attack class + scope + approach
4. ESTIMATE: berapa deep per hypothesis (quick probe vs deep investigation)
5. PLAN task queue: urutan optimal (high-priority first, dependencies resolved)

Plan ini MENCEGAH "wandering" — setiap aksi ada TUJUAN JELAS dari plan.
Tanpa plan → model akan drift ke area comfortable, miss area critical.
```

---

### PRIMITIVE CHAIN DECOMPOSITION (Stage 9 — Sebelum exploit dev)

Source: CVE-2026-2796 transcript — Claude EXPLICITLY decomposes exploit goal ke primitive chain DI AWAL:
"1. UAF → type confusion. 2. Type confusion → info leak. 3. Info leak → arbitrary R/W. 4. Arbitrary R/W → code execution."

```
SEBELUM mulai exploit development:
1. LIST all confirmed primitives (HAVE):
   "Saya PUNYA: OOB read 1 byte, controlled crash, info leak via timing"
2. DEFINE end goal (NEED):
   "Saya BUTUH: arbitrary code execution sebagai root"
3. MAP the chain: HAVE → ??? → NEED
   "OOB read → KASLR bypass → ??? → write primitive → cred overwrite → root"
4. IDENTIFY gaps:
   "Gap: saya belum punya WRITE primitive"
5. HUNT for gap-filler:
   - Cari vuln kedua yang memberikan write
   - ATAU: lateral approach (CVE-2026-2796: WasmGC struct.get sebagai alternative read tanpa perlu write dulu)

CHICKEN-AND-EGG: "Need write to GET write" → JANGAN stuck.
Cari LATERAL ALTERNATIVE: primitif berbeda yang achieve same goal tanpa circular dependency.
```

---

### FOCUSED CoT (Spesifik = Better, Generik = Worse)

Source: Mythos research — "Unfocused CoT (naive line-by-line analysis) HURTS performance.
Irrelevant vulnerability types in reasoning reduced F1 from 36.34% to 26.37%."

```
WRONG (unfocused): "Analyze this code for any vulnerabilities"
  → Model wanders, considers irrelevant classes, shallow on all

RIGHT (focused): "In function parse_header() at line 247:
  1. Parameter 'content_length' is user-controlled (from HTTP header)
  2. It's used in malloc(content_length + 1) at line 263
  3. CHECK: can content_length overflow when +1 is added?
  4. CHECK: is the malloc result bounds-checked before memcpy at line 270?"
  → Model focuses on SPECIFIC sink, SPECIFIC input, SPECIFIC vulnerability class

RULE: Setiap task di ULTRAPLAN harus spesifik:
  - WHAT function/endpoint
  - WHAT attack class
  - WHAT input reaches it
  - WHAT to check specifically
```

---

### EXPLOIT DETERMINISM (Stability as Explicit Goal)

Source: ExploitBench CVE-2023-6702 — "Mythos created a near-DETERMINISTIC exploit where publicly known exploits were PROBABILISTIC. The original human author DISMISSED this approach due to complexity. Mythos executed it cleanly."

```
GOAL: 95%+ reliability, bukan "sometimes works"

TECHNIQUES for determinism:
1. Heap grooming: precise alloc/free order → control freelist
2. CPU pinning: sched_setaffinity → deterministic SLUB behavior
3. Verification at each step: read back corrupted value BEFORE using
4. Recovery on failure: catch SIGSEGV → retry with adjusted parameters
5. GC control: force/prevent GC at specific points (browser exploits)

SETIAP exploit, test N=10 kali:
- 8+/10 success = RELIABLE → ship
- 4-7/10 = FLAKY → stabilize (heap groom, timing, retry)
- <4/10 = UNRELIABLE → rethink approach
```

---

### ANTI-CHEATING (Verify PoC Exploits INTENDED Vulnerability)

Source: CVE-2026-2796 eval — "The verifier required multiple iterations of hardening
as Claude found increasingly clever ways to CHEAT the verifier that didn't technically count as an exploit."

```
SETIAP PoC yang berhasil, VERIFY:
1. Apakah PoC exploit INTENDED vulnerability, atau shortcut/different bug?
2. Apakah PoC bekerja di FRESH environment (bukan hanya environment yang sudah di-groom)?
3. Apakah success reproducible tanpa prior state setup?
4. Apakah impact yang di-claim MATCH dengan apa yang PoC demonstrate?

JANGAN claim "RCE" jika PoC hanya demonstrate crash.
JANGAN claim "auth bypass" jika PoC requires admin cookie.
PoC harus PROVE exact impact yang di-claim, bukan lebih bukan kurang.
```

---

### ANTHROPIC OFFICIAL LESSONS (From claude.com/blog/using-llms-to-secure-source-code, May 2026)

7 pelajaran dari tim Anthropic + partner security teams yang WAJIB diterapkan:

**L1: SIMPLE DISCOVERY PROMPTS — Prescriptive checklists HURT discovery**
```
"More prescriptive prompts make discovery WORSE — long checklists reduce
the model's creativity and generate fewer novel bugs."

RULE: Discovery prompt = SIMPLE (goal + context + what a finding looks like)
  BUKAN checklist panjang tentang HOW to scan.
  Biarkan model sendiri yang decide HOW.
  
CLARIFICATION: Focused CoT = specify WHAT class to look for (e.g. "SQLi in ORDER BY")
  BUKAN HOW to look for it. Model sudah tahu HOW — kita guide WHAT.
  
Checklists (E1-E9, H1-H9) = untuk ENFORCEMENT/PROCESS,
  BUKAN untuk disisipkan ke discovery prompt.
```

**L2: SELF-CENSORING PREVENTION — Discovery ≠ Verification**
```
"When discovery agents were also asked to verify findings, they filtered out
true positives that a separate verification step would have confirmed."

RULE: Discovery agent HANYA mencari. JANGAN minta dia juga verify.
  "Ini mungkin vuln TAPI..." → discovery should REPORT it anyway.
  Verification agent (Stage 5) yang decide TRUE/FALSE.
  Combining discovery + verification = KEHILANGAN true positives.
```

**L3: UNPROVEN FINDINGS — Flag, Don't Discard**
```
"Failure to produce a working PoC is NOT proof of a false positive."

RULE: Discovery tanpa PoC = flag sebagai "UNPROVEN", BUKAN discard.
  Tier escalation tetap butuh PoC (Quality-Tier Rubric).
  TAPI: discovery phase boleh report tanpa PoC → flagged untuk verification.
  Verification agent yang coba build PoC. Gagal build ≠ false positive.
```

**L4: SHOSTACK'S 4 QUESTIONS — Threat Model Interview Framework**
```
Saat interview/build threat model, gunakan framework Adam Shostack:
1. "What are we BUILDING?" → architecture, components, data flows
2. "What can GO WRONG?" → threats, attack vectors, abuse scenarios
3. "What are we DOING about it?" → existing controls, mitigations
4. "Did we do a GOOD JOB?" → gaps, coverage, confidence level

Bootstrap dari code/docs/CVE history DULU → interview refine.
```

**L5: BUG-SHAPE HINTS — Past CVEs as Discovery Templates**
```
"One team reviewed hundreds of past CVE commits, distilled them into
'bug-shape' hints, and asked: was the fix complete? Was it applied everywhere?
Found three exploitable issues in an hour."

RULE: Di Stage 3 RECON (patch gap), JANGAN hanya cari incomplete fixes.
  JUGA distill past CVEs ke "bug shapes" — abstracted patterns:
  - "memcpy with user-controlled size without overflow check" (shape)
  - "strcat chain without total length validation" (shape)
  - "deserialization of user input without class whitelist" (shape)
  Lalu: grep codebase for matching shapes → priority hypotheses.
```

**L6: DEPENDENCY SECURITY POLICIES — Read Before Scanning**
```
"Many open-source projects publish security policies. Your threat model
should consider them directly instead of rebuilding from scratch."

RULE: Di Stage 2 RECON, cari dan BACA:
  - Target's SECURITY.md / security policy
  - Dependencies' security policies (apa yang mereka anggap trusted/untrusted)
  - Known limitations yang di-acknowledge vendor

Ini mencegah false positives dari assumptions yang salah tentang trust boundaries.
```

**L7: PATCH ADVERSARIAL TESTING — Attack the Fix, Not Just the Code**
```
"Have a new discovery agent probe the patch as an attacker to confirm
the patch is comprehensive."

Patch verification ladder (4 checks):
1. BUILD — patch compiles, new tests pass
2. REPRODUCE — original PoC STOPS working (patch effective)
3. REGRESSIONS — original test suite still passes (nothing broken)
4. RE-ATTACK — fresh discovery agent tries to BYPASS the patch

Juga: "Minimal patches — smallest change that fixes ROOT CAUSE.
No refactoring, no drive-by cleanups, no reformatting."
```

---

### ACADEMIC RESEARCH DIMENSIONS (arXiv 2025-2026 — Beyond Mythos Public Sources)

9 dimensi reasoning dari Co-RedTeam (Google), DrillAgent (UIUC), LogiSec, Aegis, Phoenix.

**R1: 3-LAYER MEMORY (Co-RedTeam — Google, Feb 2026)**
```
Bukan 1 flat memory — tapi 3 LAYER yang serve purpose berbeda:

LAYER 1 — VULNERABILITY PATTERN MEMORY:
  Confirmed vuln schemas: symptom → hypothesis → confirming test + common FALSE LEADS
  e.g., "URL fetch function benign UNLESS combined with specific config flag"
  → Rapid recognition of recurring patterns across targets

LAYER 2 — STRATEGY MEMORY:
  High-level exploitation workflows yang TRANSFER across targets
  Successes: "prioritize config analysis BEFORE payload crafting"
  Failures: "blind fuzzing WITHOUT understanding execution context = dead end"
  → Guide planning toward effective directions

LAYER 3 — TECHNICAL ACTION MEMORY:
  Concrete commands/scripts — what WORKED and what FAILED
  Successes: "working SSRF test command for this framework"
  Failures: "incorrect file path assumption + the fix"
  → Reduce trial-and-error at execution level

Map ke MCP Memory: Pattern=TEKNIK, Strategy=EXPLOIT, Action=RE-ENTRY CHECKLIST
```

**R2: ANALYSIS-CRITIQUE ITERATIVE LOOP (Co-RedTeam)**
```
Ablation data: removing critique = performance drop on detection.
3 rounds MINIMUM antara discovery dan conclusion:

Round 1: Analysis agent → generate vulnerability hypotheses with evidence
Round 2: Critique agent → review each: APPROVED / REJECTED / NEEDS REFINEMENT
  - Rejected: "evidence insufficient, no concrete code path"
  - Needs refinement: "plausible but need stronger proof at [location]"
Round 3: Analysis agent → strengthen evidence OR discard unsupported

ITERATE sampai stable set of well-supported hypotheses.
Ini BERBEDA dari adversarial validation (post-discovery) — ini DURING discovery.
```

**R3: PRE-EXECUTION VALIDATION GATE (Co-RedTeam)**
```
Ablation data: removing validation = 6.8% drop on CyBench.
SEBELUM setiap command/exploit dieksekusi, VERIFY:

□ Well-formed? (syntax correct, no typos)
□ Aligned with intended goal? (does this actually test what I think?)
□ Compatible with observed system state? (target still accessible? right version?)
□ Not repeating a known-failed action? (check dead_ends)
□ Side effects acceptable? (won't crash target? won't alert defender?)

Only VALIDATED actions proceed. Invalid → refine first.
Ini mencegah wasted iterations pada malformed/wrong commands.
```

**R4: EXPLICIT EXPLOIT PLAN WITH STATUS (Co-RedTeam)**
```
Setiap step dalam exploit plan punya STATUS:

| Step | Goal | Action | Status |
|------|------|--------|--------|
| 1 | Map attack surface | rustscan + crawl | ✅ done |
| 2 | Test auth bypass | Remove token on /admin | ✅ done (403) |
| 3 | Test IDOR on /api/users/{id} | Change ID parameter | 🔄 testing |
| 4 | If IDOR confirmed → chain with file read | Path traversal | ⏳ planned |
| 5 | Test race condition on /api/transfer | Concurrent requests | ⛔ blocked (need auth first) |

PROACTIVE REVISION: Setelah setiap execution, update FUTURE steps berdasarkan hasil.
Jika step 3 gagal → step 4 mungkin perlu diubah. JANGAN blindly follow outdated plan.
```

**R5: DIALECTICAL VERIFICATION (Aegis — arXiv 2026)**
```
LEBIH KUAT dari adversarial validation biasa.
Satu verifier WAJIB build KEDUA argument:

PROSECUTION CASE: "Bug INI REAL karena..."
  - Input X reaches sink Y via path Z
  - No sanitizer blocks it
  - Impact: attacker can [specific action]

DEFENSE CASE: "Bug ini FALSE POSITIVE karena..."
  - Actually, sanitizer at line N blocks this
  - Actually, this code path is unreachable because [condition]
  - Actually, impact is limited to [less severe than claimed]

META-AUDIT: Independent review of KEDUA argument — mana yang LEBIH KUAT?
Prosecution wins → CONFIRMED. Defense wins → DISMISSED.

Ini mencegah confirmation bias (hanya cari bukti yang SUPPORT finding).
```

**R6: BEHAVIORAL CONTRACT SYNTHESIS (Phoenix — arXiv 2026)**
```
Transform vulnerability detection dari open-ended search → CONTRACT VERIFICATION.
Gunakan Gherkin Given-When-Then format:

UNTUK SETIAP endpoint/function:
  Given: [preconditions — user authenticated, valid session, normal input]
  When: [action — send request with [specific parameter]]
  Then: [expected SECURE behavior — reject invalid input, return 403, sanitize]

LALU TEST: Apakah code VIOLATE the "Then" clause?
  Given: user authenticated as regular user
  When: access /api/admin/users
  Then: SHOULD return 403 Forbidden
  ACTUAL: Returns 200 with all user data → CONTRACT VIOLATED → VULNERABILITY

Ini FORMALISASI dari Layer 2 (Intent Modeling) menjadi VERIFIABLE specification.
```

**R7: CWE-SYSTEMATIC ENUMERATION (Co-RedTeam + SecPI)**
```
JANGAN random hunt — ground analysis dalam CWE taxonomy:

UNTUK SETIAP target function/endpoint:
1. ENUMERATE relevant CWEs berdasarkan teknologi dan context:
   - PHP: CWE-502 (deserialization), CWE-78 (OS command), CWE-89 (SQLi)
   - Java: CWE-917 (expression injection), CWE-611 (XXE), CWE-502
   - Node.js: CWE-1321 (prototype pollution), CWE-918 (SSRF), CWE-94 (code injection)
2. UNTUK SETIAP applicable CWE: formulate SPECIFIC hypothesis
3. TEST hypothesis systematically
4. RECORD: CWE tested + result (confirmed/refuted/needs more testing)

Ini PREVENTS missing entire vulnerability classes karena "lupa test."
```

**R8: EXECUTION-STATE-TO-SOURCE MAPPING (DrillAgent — UIUC 2026)**
```
KETIKA debug/execute code:
1. OBSERVE execution trace (which lines executed, variable values, branch taken)
2. TRANSLATE low-level trace ke SOURCE-LEVEL constraints:
   "Execution took branch at line 247 because content_length > 128"
   → Source constraint: "Need content_length > 128 to reach vulnerable memcpy"
3. USE constraints untuk construct PRECISE trigger input
4. ITERATE: refine input → observe new trace → extract new constraints → refine again

Ini BERBEDA dari blind debug — ini systematic CONSTRAINT EXTRACTION dari execution.
Setiap execution TEACHES something specific tentang path ke vulnerability.
```

**R9: REDUCTIO AD ABSURDUM (LogiSec — LADC 2025, published Feb 2026)**
```
4-step formal reasoning untuk SETIAP candidate vulnerability:

STEP 1: ASSUME vulnerability EXISTS (hypothesis)
STEP 2: Try to prove it DOES NOT exist (attempt refutation):
  - "If input IS sanitized at [location], then vulnerability cannot trigger"
  - CHECK: is input actually sanitized? → read code → verify
STEP 3: If CONTRADICTION found (refutation fails — sanitizer doesn't exist or is bypassable):
  → Vulnerability CONFIRMED (existence cannot be disproven)
STEP 4: If refutation SUCCEEDS (sanitizer exists and works):
  → Vulnerability REFUTED (existence disproven)

LEBIH RIGOROUS dari "try to disprove" karena:
- Structured 4-step process, bukan ad-hoc skepticism
- FORMAL: if you can't prove non-existence → existence confirmed
- Reduces false positives significantly (paper: meaningful FP reduction)
```

---

### ADVANCED RESEARCH DIMENSIONS (arXiv 2026 — Sub-Agent Deep Research)

7 dimensi dari Refute-or-Promote, Cve2PoC, VulnSage, AgentFlow, EnIGMA, Bugonomics.

**R10: CROSS-FAMILY CRITIC — Same-Model Blind Spots (Refute-or-Promote, arXiv 2604.19049)**
```
PROBLEM: 80+ same-family agents UNANIMOUSLY endorsed a non-existent Bleichenbacher
oracle in OpenSSL. ALL wrong — shared training-data bias.

SOLUTION: Untuk finding T1-SUBMIT, kirim ke reasoning angle yang BERBEDA TOTAL:
  - Angle A: analisis dari perspektif code-level (normal)
  - Angle B: analisis dari perspektif attacker (CTF framing)
  - Angle C: analisis TANPA context reasoning agent pertama (cold-start, hanya PoC)

Cold-start critic (Angle C) KRITIS — dia tidak ter-anchor oleh reasoning sebelumnya.
Jika C disagree dengan A+B → INVESTIGASI LEBIH DALAM, jangan majority-vote.
```

**R11: UNANIMITY = WARNING SIGNAL + RESURRECTION (Refute-or-Promote)**
```
RULE: Ketika SEMUA reasoning angles SETUJU (baik "vuln" maupun "not vuln"):
  → INI BUKAN high confidence — ini MUNGKIN shared blind spot

KASUS NYATA:
  - wolfSSL: 3 agents unanimously wrong byte-ordering → cold-start senior caught it
  - lcms2: unanimously killed as "not exploitable, 174MB trigger" → resurrection
    agent found 4.8KB trigger → valid CVE-2026-41254

RESPONSE: Setelah unanimous KILL, jalankan RESURRECTION check:
  "Apakah ada cara trigger ini yang LEBIH KECIL/SEDERHANA dari yang sudah dicoba?"
  "Apakah reasoning semua setuju karena BUKTI atau karena ASUMSI yang sama?"
```

**R12: KILL MANDATE + CONTEXT ASYMMETRY (Refute-or-Promote)**
```
UPGRADE dari adversarial validation biasa:

CONTEXT ASYMMETRY: Adversarial reviewer HANYA terima CLAIM + PoC.
  TIDAK terima reasoning chain dari discoverer.
  → Mencegah anchoring cascade (reviewer setuju karena baca reasoning, bukan karena bukti)

KILL MANDATE: Reviewer job = DESTROY finding, bukan refine.
  "Tugas mu SATU: buktikan finding ini SALAH. Jika tidak bisa = finding SURVIVE."

STAGE-GATED (bukan iterative — iterative MENURUNKAN quality setelah round 3):
  Stage A: 1 creative + 2 adversarial (claim-only context)
  Stage B: senior-tier adversarial (mixed context depths)
  Stage C: mandatory empirical validation (oracle)
  Stage D: cross-perspective critic (cold-start)
```

**R13: STRATEGY vs TACTICS DUAL-LOOP (Cve2PoC, arXiv 2602.05721)**
```
KETIKA exploit GAGAL, diagnosa DULU: salah STRATEGY atau salah IMPLEMENTATION?

TACTICAL failure (salah implementasi):
  - Python syntax error, wrong file path, incorrect offset
  - FIX: perbaiki code-level issue, PERTAHANKAN attack strategy
  - Tactical Loop: Executor → Refiner → Executor (fix implementation)

STRATEGIC failure (salah vulnerability model):
  - Bug tidak ada di sini, wrong assumption about code behavior
  - FIX: kembali ke Strategic Planner, revisi vulnerability hypothesis
  - Strategic Loop: Planner → re-analyze → new strategy

RULE: JANGAN endlessly refine implementation jika strategy yang salah.
  JANGAN abandon valid strategy karena fixable implementation mistake.
  Diagnosa DULU: "Apakah PoC gagal karena BUG DI EXPLOIT CODE atau karena
  VULNERABILITY MODEL yang salah?"
```

**R14: CONSTRAINT-GUIDED EXPLOIT GENERATION (VulnSage, arXiv 2604.05130)**
```
Formalisasi exploit sebagai CONSTRAINT SATISFACTION:

1. Dari vulnerability analysis → extract FORMAL CONSTRAINTS:
   "input HARUS >128 bytes" + "byte 96 HARUS = 0x00" + "must reach line 247"
2. Generate exploit code yang SATISFY semua constraints
3. Jika GAGAL → derive NEW constraints dari failure:
   "constraint baru: server timeout setelah 5s, jadi payload harus <1KB"
4. ITERATE: constraints refine → exploit refine → test → new constraints

BERBEDA dari trial-and-error: setiap failure TEACHES specific constraint.
Constraints ACCUMULATE — setiap attempt gets CLOSER, bukan random restart.
```

**R15: SOLILOQUIZING DETECTION (EnIGMA, ICML 2025)**
```
PATHOLOGY #6 (tambahan dari 5 detector existing):

SOLILOQUIZING: Agent BERHENTI memanggil tools dan MEMBAYANGKAN output.
  Agent "pura-pura" command berhasil, build di atas hasil imaginer,
  masuk self-referential loop dimana TIDAK ADA yang correspond ke realitas.

DETECTION: Setiap "hasil" yang di-claim → VERIFIKASI ada actual tool call.
  Jika agent bilang "saya sudah scan dan menemukan..." tapi TIDAK ADA Bash call → SOLILOQUIZING.

RESPONSE: STOP → jalankan command SEBENARNYA → baca output ASLI.
```

**R16: PoC SELF-CONTAMINATION (Refute-or-Promote — wolfSSL campaign)**
```
PROBLEM: PoC mengukur KOMPUTASI SENDIRI, bukan behavior TARGET.

KASUS NYATA: wolfSSL campaign — PoC measured its OWN nonce computation
  instead of the LIBRARY's leak. Produced false-positive confirmation.

CHECK setiap PoC:
  "Apakah PoC ini mengukur behavior TARGET atau behavior DIRI SENDIRI?"
  "Apakah oracle (crash/diff/output) berasal dari TARGET process atau PoC script?"
  "Jika PoC dihapus dan target dijalankan manual dengan input yang sama,
   apakah hasilnya SAMA?"

PoC yang test dirinya sendiri = FALSE POSITIVE. Wajib test TARGET directly.
```

---

## THE PROCESS — 5 LAYERS (Stage 4 HUNT — Urutan per hypothesis)

### LAYER 1: RECONSTRUCT — Bangun Mental Model Target dari Luar

Sebelum kirim SATU PAYLOAD pun, habiskan waktu untuk MEMAHAMI target:

```
1. Download + beautify SEMUA JavaScript
   → Extract: API endpoints, auth logic, hidden routes, WebSocket, secrets
   → Trace: fetch()/axios/XMLHttpRequest calls → map SEMUA server endpoints
   
2. Capture baseline responses dari SETIAP endpoint ditemukan
   → Headers, cookies, error formats, redirect patterns, timing
   
3. Identify technology stack dari responses
   → Server header, cookie names, error page format, JS framework
   
4. Map authentication model
   → Token type (JWT/session/API key)? Where stored? How validated?
   → Which endpoints need auth? Which DON'T? (inconsistency = vuln)
   
5. Map data model dari response structure
   → Object IDs (sequential? UUID?), field names, relationships
   → Which fields user-controllable? Which server-generated?

6. Map trust boundaries
   → Unauthenticated → Authenticated → Admin → System
   → Per-endpoint: which boundary SHOULD apply? 

7. Map business flows
   → Registration, login, payment, transfer, upload, export
   → Multi-step processes: apa urutan yang SEHARUSNYA?
```

**OUTPUT LAYER 1**: Complete mental model — "Saya PAHAM apa yang app ini LAKUKAN."
**TANPA layer 1 selesai → DILARANG mulai attack. Ini non-negotiable.**

---

### LAYER 2: INTENT MODELING — Apa yang App SEHARUSNYA Lakukan?

Untuk SETIAP endpoint/function yang ditemukan di Layer 1:

```
FORMULATE INTENT:
- "/api/orders/{id}" SEHARUSNYA: hanya return order milik requester
- "/api/users/{id}/update" SEHARUSNYA: hanya bisa update DIRI SENDIRI
- "/api/admin/..." SEHARUSNYA: hanya accessible oleh role admin
- "/api/coupon/redeem" SEHARUSNYA: 1 coupon = 1 kali pakai, atomic
- "/api/transfer" SEHARUSNYA: sender = current user, balance sufficient
- "/api/upload" SEHARUSNYA: hanya file types tertentu, size limited
- "/api/export" SEHARUSNYA: hanya data milik requester

SUMBER INTENT (bagaimana infer tanpa source):
- Naming convention: "admin" di path = role restriction expected
- Response structure: "owner_id" field = ownership check expected
- Business logic: payment endpoint = atomic transaction expected  
- Common sense: user A data ≠ accessible by user B
- Documentation/help: API docs, UI labels, error messages
```

**OUTPUT LAYER 2**: List of "SEHARUSNYA" per endpoint.
**Ini menjadi checklist untuk Layer 3.**

---

### LAYER 3: DIVERGENCE HUNT — Cari Dimana Reality ≠ Intent

Untuk SETIAP "SEHARUSNYA" dari Layer 2, TEST apakah BENAR ditegakkan:

```
DIVERGENCE PATTERNS (test setiap satu):

AUTH DIVERGENCE:
- Endpoint yang SEHARUSNYA auth → coba tanpa token → access?
- Endpoint yang SEHARUSNYA admin → coba dengan user token → access?
- Auth check di GET → apakah juga di POST/PUT/DELETE?
- Auth di /api/v2 → apakah /api/v1 juga? (lupa migrate middleware)
- Auth setelah reverse proxy → spoof X-Forwarded-* headers?

OWNERSHIP DIVERGENCE (IDOR):
- Object milik user A → request dengan user B token → dapat?
- Sequential ID → iterate ID → enumerate semua objects?
- UUID tapi predictable → pattern?
- Nested resource: /users/A/orders/1 → /users/B/orders/1?

LOGIC DIVERGENCE:
- Coupon: apply 2x bersamaan (race condition)?
- Transfer: ubah amount ke negatif? Ke float precision?
- Price: kirim custom price di request body? Discount > 100%?
- Steps: skip step 2, langsung ke step 4?
- Limits: kirim parallel → bypass rate/count limit?

VALIDATION DIVERGENCE:
- Filter char X → tapi tidak filter char Y yang equivalent?
- Validate di frontend → tapi backend SKIP validation?
- Parameter di query string divalidasi → tapi sama param di JSON body TIDAK?
- Content-Type restriction → tapi server parse apapun?

BOUNDARY DIVERGENCE:
- Path normalization: /admin/../public vs /admin?
- Encoding: %2f vs / treated differently by proxy vs app?
- Method: GET blocked → tapi POST/OPTIONS/PATCH?
- Host header: virtual host routing manipulable?
```

**PROTOCOL**: Untuk setiap divergence candidate:
1. FORMULATE hypothesis: "Jika saya lakukan X, MAKA Y akan terjadi (violating intent)"
2. PREDICT expected response jika vuln vs jika patched
3. EXECUTE precise test
4. COMPARE result vs prediction
5. DIVERGENCE FOUND? → Layer 4. Not found? → next candidate.

---

### LAYER 4: PROVE — PoC atau Iterate

```
FINDING TANPA PoC = BUKAN FINDING.

Ketika divergence ditemukan:
1. Build MINIMAL reproducible PoC (curl command, Python script)
2. Verify PoC works CONSISTENTLY (bukan flaky)
3. Document: request, response, impact, preconditions
4. MEASURE impact: apa WORST CASE yang bisa attacker lakukan?

Ketika divergence TIDAK ditemukan setelah test:
- BUKAN "not vulnerable" — mungkin TEST yang salah
- ASK: "Approach lain untuk trigger ini?"
- ASK: "Encoding berbeda? Timing berbeda? Context berbeda?"
- ASK: "Endpoint LAIN yang sama function tapi beda implementation?"
- ITERATE sampai EITHER: PoC works OR proven impossible (10+ angles tried)
```

---

### LAYER 5: CHAIN & ESCALATE

```
SETIAP finding → MAP ke PRIMITIVE:
- Info disclosure → "Saya bisa BACA [apa]"
- IDOR → "Saya bisa ACCESS [resource] milik [siapa]"
- XSS → "Saya bisa EXECUTE JS di context [user]"
- SSRF → "Saya bisa REACH [internal service]"
- Upload → "Saya bisa WRITE [file] di [location]"
- Race → "Saya bisa BYPASS [limit/check]"
- Open redirect → "Saya bisa REDIRECT [user] ke [attacker]"

LALU ASK: "Primitive apa yang KURANG untuk full impact?"
- Punya read tapi perlu write → hunt write primitive
- Punya auth bypass tapi perlu target → hunt admin endpoint
- Punya SSRF tapi perlu creds → check cloud metadata

CHAIN EXAMPLES:
- IDOR (read user data) + info disclosure (admin email) + password reset = ACCOUNT TAKEOVER
- SSRF (hit internal) + cloud metadata (get AWS creds) = CLOUD TAKEOVER
- XSS (steal token) + CSRF (change email) + password reset = FULL COMPROMISE
- Race (bypass limit) + coupon logic (negative price) = FINANCIAL LOSS
- File upload (write .php) + path traversal (control location) = RCE
```

---

## HARNESS PRINCIPLES — What Makes Opus 4.6 Match Mythos

Source: Mozilla (271 bugs, almost no FP), Cloudflare (7-stage pipeline), XBOW, Vidoc, Hacktron.
Key fact: "The harness did the work, not the model." — Mozilla. "Architecture is the moat, not the weights." — Cloudflare.

### H1: VERIFICATION LOOP (Eliminates False Positives)

```
Mozilla's win condition: "Trip the sanitizer OR keep working."
Our win condition: "Produce OBSERVABLE DIVERGENCE or keep iterating."

FOR EVERY HYPOTHESIS:
1. BUILD testcase — specific request/script that would PROVE the bug
2. RUN testcase — execute against live target
3. OBSERVE result — did expected divergence happen?
   YES → finding CONFIRMED (with proof)
   NO → WHY not? → adjust hypothesis → BUILD new testcase → RUN again
4. CANNOT reproduce after 5+ attempts → DISMISS (not a finding)

RULE: "Might be vulnerable" tanpa reproducible proof = NOT A FINDING.
RULE: NEVER report without executable PoC (curl command, Python script).
RULE: Model inability to reproduce ≠ "not vulnerable" — it means TRY HARDER or TRY DIFFERENT ANGLE.
```

### H2: SPLIT STAGES (Don't Ask Everything at Once)

```
From Cloudflare: "Asking the model BOTH questions in one prompt produces WORSE answers to both."

WRONG (what I used to do):
  "Find vulnerability AND prove it's exploitable AND assess impact" → all in 1 thought
  Result: shallow on all 3, misses subtle bugs

RIGHT (split into stages):
  STAGE A — HUNT: "Is there a potential flaw in how this endpoint handles [X]?"
    Focus ONLY on finding the logical weakness
    
  STAGE B — REACH: "Can attacker-controlled input reach this flaw from outside?"
    Focus ONLY on reachability — auth, routing, input flow
    
  STAGE C — PROVE: "Build a specific request that triggers this flaw"
    Focus ONLY on constructing reproducible PoC
    
  STAGE D — IMPACT: "What's the worst-case outcome if attacker exploits this?"
    Focus ONLY on measuring damage potential

Each stage gets FULL attention. No stage pollutes another.
```

### H3: MULTIPLE ATTEMPTS with DIVERSITY (Compensate for Reasoning Gap)

```
From Hacktron: "Small models find same 0-days, just less reliably. Run multiple times."
From Mozilla: "Optional diversity hint for exploration variation."

PER INTERESTING ENDPOINT — run 3-5 attempts with DIFFERENT angles:
  Attempt 1: Focus on AUTH boundaries — "Is auth check consistent across methods?"
  Attempt 2: Focus on DATA FLOW — "Where does user input end up? Any unvalidated paths?"
  Attempt 3: Focus on TIMING — "Is any check-then-act non-atomic? Race window?"
  Attempt 4: Focus on BUSINESS LOGIC — "Can workflow be abused by changing order/values?"
  Attempt 5: Focus on BOUNDARY — "Parser differences? Encoding? Normalization?"

EACH attempt approaches the SAME endpoint from DIFFERENT cognitive angle.
If attempt 1 misses auth bypass, attempt 3 might find race condition.
One-shot = near-zero probability. Five-shot from different angles = meaningful coverage.
```

### H4: IMPOSSIBLE CONDITION FORCING (What Found the 27-year OpenBSD Bug)

```
EVERY TIME you encounter a validation/check/condition, FORCE these questions:

□ "What if INTEGER OVERFLOWS here? Does signed math create impossible true?"
□ "What if TYPE JUGGLING happens? Does PHP '0' == false? Does JS '' == 0?"
□ "What if RACE CONDITION between check and use? Another thread modifies state?"
□ "What if DOUBLE ENCODING slips past filter? %2527 → %27 → ' ?"
□ "What if NULL BYTE truncates? file.php%00.jpg passes extension check?"
□ "What if LENGTH TRUNCATION changes meaning? 255-byte field cuts critical part?"
□ "What if UNICODE NORMALIZATION makes different chars equal? ℀ → a/c?"
□ "What if CASE SENSITIVITY differs between checker and executor?"
□ "What if PARSER A and PARSER B disagree on same input? Proxy vs App?"
□ "What if DEFAULT/FALLBACK case handles unexpected value unsafely?"

This is NOT optional. This is NOT "if I remember."
This is a MANDATORY checklist for EVERY non-trivial validation encountered.

The OpenBSD SACK bug: signed comparison that EVERYONE assumed couldn't satisfy both conditions simultaneously. 27 years of expert review missed it. Mythos found it by FORCING the question "what if the arithmetic lies?"
```

### H5: NARROW SCOPE (Cloudflare's #1 Lesson: "Find vulns in repo" = WANDER)

```
From Cloudflare: "Telling the model 'find vulnerabilities in this repository' makes it WANDER.
Telling it 'look for command injection in THIS function, with THIS trust boundary'
makes it do something closer to what a researcher would actually do."

WRONG: "Test this website for vulnerabilities"
RIGHT: "Test parameter 'sort' in GET /api/users for SQL injection —
        this param used in ORDER BY clause, server MySQL 8.0,
        WAF Cloudflare, responses show 500 on syntax error"

NARROW = SPECIFIC: class + endpoint + trust boundary + tech stack + observations so far.
Apply when THINKING internally — frame EACH test as narrow focused investigation.
```

### H6: FAILURE MEMORY (Never Repeat What Already Failed)

```
From Trace37: "If alert(1) failed 3+ times against Akamai, it will NOT be attempted again."

RULES:
- Same payload failed 2x = NEVER try again (adapt or abandon)
- Same approach failed 3x = SKIP this approach class entirely
- Each failure NARROWS search space (INFORMATION, not defeat)
- Before trying → CHECK: "Already tried this? Similar failed?"
- Failures TEACH blocking mechanisms → infer rule → design bypass AROUND it
```

### H7: 5-APPROACH RULE (Minimum Different Strategies Before Abandon)

```
From Trace37: "5-Approach Rule — ENFORCES 5 genuinely different approaches before abandon."
(Not 5 variations of same payload — 5 DIFFERENT cognitive strategies)

Example for auth bypass on /admin:
  1. DIRECT — access without token
  2. HEADER SPOOF — X-Forwarded-For, X-Original-URL
  3. PATH CONFUSION — /admin/../public/../admin, /ADMIN, /admin;.css
  4. METHOD OVERRIDE — X-HTTP-Method-Override on POST-only
  5. RACE/TIMING — auth check + request simultaneously

ONLY AFTER all 5 genuinely different approaches fail → allowed to conclude.
Fewer than 5 = NOT EXHAUSTED.
```

### H8: CTF ADVERSARIAL FRAMING (Carlini's Key Insight — Changes Model Reasoning)

```
From Nicholas Carlini (500+ zero-days): "Find exploitable vulnerabilities
in this code as if you're competing in a CTF competition."

WHY THIS WORKS:
- Asking "is this safe?" → model defaults to YES (agreeable bias)
- Asking "find the exploit" → activates ADVERSARIAL reasoning (SEARCH for attacks)
- CTF framing = model ASSUMES vulnerability EXISTS and works to FIND it
- This changes HOW the model thinks — not what it sees, but how it reasons

APPLY: Frame EVERY investigation as "I am looking for the exploit here"
— not "let me check if this is secure."
- "What would an attacker do with this endpoint?"
- "How would I break this in a CTF?"
- "What assumption can I violate to win?"

WRONG internal framing: "Is /api/users vulnerable?"
RIGHT internal framing: "How do I exploit /api/users to get unauthorized data?"
```

### H9: PROGRESSIVE INFERENCE (Build Server Logic Model from Response Patterns)

```
From XBOW/Hungrysoul: "The AI didn't randomly throw payloads.
It systematically narrowed down through multiple testing cycles."

AFTER EACH RESPONSE, ASK:
1. "What did I LEARN?" → extract specific intel
2. "What rule does this CONFIRM or REVEAL?" → update mental model
3. "What's the NARROWEST next test?" → maximize information gain
4. "Am I CLOSER or going in CIRCLES?" → progress check

INFERENCE PATTERNS:
- 200 on .html, 403 on .php → extension WHITELIST exists
- 200 with text/html, 403 with image/png → content-type validation
- 500 on ' but 200 on " → SQL uses single-quote context
- Same response valid/invalid ID → no DB query (static)
- Different response valid/invalid ID → DB query (injectable?)
- Slow on sleep(5) → blind injection CONFIRMED
- Redirect to /login on some but not all → INCONSISTENT auth (vuln!)

EACH RESPONSE NARROWS possible server implementations.
After 5-10 targeted probes → you have MENTAL MODEL of server behavior.
THEN craft payload that exploits the SPECIFIC rules you inferred.

THIS IS THE EXACT MECHANISM that makes iteration PRODUCTIVE (not circular):
- Circular: try random payloads, ignore responses, repeat
- Productive: probe → learn rule → design around rule → probe → learn next rule
```

---

## ENFORCEMENT — HARD BLOCKS (NON-NEGOTIABLE)

### E1: DILARANG Bilang "Not Vulnerable" KECUALI SEMUA TRUE:
- ✅ Layer 1 COMPLETE (full JS analysis + surface map + mental model built)
- ✅ Min 15+ test variations per divergence hypothesis
- ✅ PAHAMI persis WHY tests failed (bukan hanya "gagal")
- ✅ Tried alternative endpoints, parameters, encodings, methods
- ✅ Researched MCP untuk technique terbaru
- ✅ ALL attempts documented
- **Belum semua?** → "BELUM EXHAUSTED — perlu deeper testing pada [area]"

### E2: DILARANG Pindah dari Current Hypothesis KECUALI:
- ✅ Min 10 angles/variations tried
- ✅ Understand WHY SPECIFICALLY setiap attempt gagal
- ✅ Documented learnings untuk inform next hypothesis
- ✅ Attempted chain dengan findings lain

### E3: WAJIB Complete Layer 1 SEBELUM Any Attack:
- No payload TANPA full JS analysis + endpoint map + auth model understood
- "Spray-and-pray" = FATAL VIOLATION
- Layer 1 shortcuts = miss 80%+ attack surface

### E4: SETIAP Response = Intelligence:
- 403 → WHY? (WAF rule? Auth? IP? Path?) → test boundary
- 500 → Code reached! → PROGRESS, refine payload
- 200 + empty → blind execution? → OOB test
- Different errors → different code paths → map
- Timing → oracle possible
- **Min 3 intel points extracted per response.**

### E5: WAJIB Chain (DILARANG Report Isolated):
- Every finding → "What can I COMBINE this with?"
- Map to primitive → Hunt gap → Test chain end-to-end
- Low finding + Low finding = potentially Critical chain

### E6: Adversarial Self-Challenge SEBELUM Conclude:
- "Layer 1 complete?" / "All 'SEHARUSNYA' tested?" / "All divergence angles tried?"
- "Apa yang saya SKIP?" / "Alternative path?" / "Race window?" / "Different param?"
- **Satu pun belum → JANGAN conclude.**

### E7: Payload Blocked ≠ Not Vulnerable:
- Blocked = INFORMATION about filter → infer → bypass
- Min 10 bypass attempts per filter
- Research MCP untuk bypass terbaru sebelum menyerah

### E8: MINIMUM Depth:
- Per target: Layer 1 complete (full surface map) before ANY attack
- Per hypothesis: min 10 variations before abandon
- Per vuln class: min 15+ unique tests across all endpoints
- Total: JANGAN declare "secure" sebelum ALL Layer 2 intents tested

### E9: FATAL VIOLATIONS:
```
🚫 Attack tanpa Layer 1 complete → STOP, go back, do Layer 1
🚫 "Patched" after <5 attempts → restart, 3x depth
🚫 Skip endpoint as "boring" → test it
🚫 Spray generic payload → stop, understand, THEN craft
🚫 Ignore response → re-analyze
🚫 Report without PoC → build PoC or retract
🚫 Fail to chain → review ALL, attempt ALL combinations
🚫 Give up on WAF → research 10+ bypasses
🚫 Conclude tanpa self-challenge → go through checklist
```

---

## REACHABILITY GATE — Stage 5 TRACE (Mandatory sebelum report)

"Flaw" ≠ "Vulnerability". Flaw = bug di code. Vulnerability = flaw yang REACHABLE oleh attacker.

```
UNTUK SETIAP confirmed finding:
1. TRACE INPUT: Apakah attacker-controlled input SAMPAI ke vulnerable sink?
2. TRACE PATH: Lewat jalur mana? (entry → middleware → handler → function → sink)
3. SANITIZERS: Ada sanitizer di jalur? Bisa di-bypass? Sudah dicoba?
4. POSITION: Dari posisi attacker REALISTIC (unauthenticated remote? local user?)
5. VERDICT:
   REACHABLE → ini VULNERABILITY → lanjut ke Chain & Report
   UNREACHABLE → ini FLAW → record, cari alternative path, JANGAN report sebagai vuln
```

DILARANG report flaw sebagai vulnerability tanpa reachability proof.

---

## ADVERSARIAL VALIDATION — Stage 4 VALIDATE (Separate Perspective)

Setelah finding confirmed, WAJIB switch ke adversarial perspective:

```
SKEPTIC MODE — "Tugas saya MEMBUKTIKAN finding ini FALSE POSITIVE":
□ "Code path ini sebenarnya UNREACHABLE karena [reason]?"
□ "Sanitizer di [location] sebenarnya BLOCKING input ini?"
□ "Impact sebenarnya LEBIH RENDAH karena [mitigation]?"
□ "Exploit condition membutuhkan [unrealistic precondition]?"
□ "Target version sudah PATCH ini di [commit/update]?"
□ "PoC bekerja hanya di kondisi [non-default/unrealistic]?"

JIKA skeptic GAGAL refute (semua jawaban = tidak) → CONFIRMED HIGH CONFIDENCE
JIKA skeptic BERHASIL refute (satu+ jawaban = ya) → downgrade tier atau dismiss
```

---

## PATHOLOGY DETECTION — Self-Monitor (cek setiap 10 aksi)

| Pathology | Detection Signal | Response |
|-----------|-----------------|----------|
| **STUCK** | >5 attempts pada 1 hypothesis tanpa progress | STOP → RCA why gagal → pivot angle |
| **LOOPING** | Variasi yang SAMA diulang (cek dead_ends) | STOP → baca dead_ends → genuinely different approach |
| **DRIFTING** | Pindah attack class tanpa exhaust current | STOP → kembali, complete min requirements E2 |
| **SPRAYING** | Payload tanpa hypothesis (no code reading) | STOP → READ code → UNDERSTAND → craft specific |
| **HALLUCINATING** | Claim vuln tanpa executable PoC | STOP → BUILD PoC → RUN → baca OUTPUT |
| **SOLILOQUIZING** | Claim hasil tanpa actual tool call (imagined output) | STOP → RUN command SEBENARNYA → baca output ASLI |

Self-check: "Am I stuck/looping/drifting/spraying/hallucinating/soliloquizing?" → YES = STOP + correct.

---

## MEMORY INTEGRATION — Writeback During Hunting

| Event | Target Section | Timing |
|-------|---------------|--------|
| Hypothesis confirmed (PoC works) | EXPLOIT | SEGERA (next tool call) |
| Hypothesis refuted + WHY | GAGAL | SEGERA (jangan ulangi) |
| Credential ditemukan | CREDENTIAL | SEGERA |
| New attack surface mapped | RECON | SEGERA |
| Chain constructed | EXPLOIT | SEGERA |
| Threat model generated | INFO / RECON | Setelah Stage 2 |
| Dead-end reached + WHY | GAGAL | SEGERA |
| Status change (access gained/lost) | LIVE STATUS | SEGERA |

**RULE**: 1 event = 1 write. Hunting tanpa writeback = data HILANG saat compaction.
**FLOW**: memory_get (UNLOCK) → Read .md (BACA ISI) → cek existing → upsert (NEW=append, UPDATE=replace_entry, SAMA=SKIP)

---

## WHEN STUCK — Decision Protocol

```
GAGAL menemukan divergence setelah thorough testing?

1. EXPAND SURFACE: "Ada endpoint yang belum di-map?"
   → Re-crawl, re-fuzz, re-analyze JS, check old API versions
   
2. CHANGE ANGLE: "Vulnerability class lain yang belum dicoba?"
   → Riset MCP: teknik apa yang applicable untuk stack ini?
   
3. DEEPEN CURRENT: "Sudah coba semua encoding/timing/context?"
   → Race condition? Second-order? Different HTTP method?
   
4. CHAIN PARTIALS: "Partial findings bisa combined?"
   → Low-sev info leak + Low-sev SSRF = High impact?
   
5. RESEARCH DEEP (WAJIB gunakan ALL MCP tools):
   → MCP Aura: "is [CVE] patched in [exact version]? what exploit exists?"
   → MCP Jina search_web: "[target stack] [vuln class] bypass technique 2025 2026"
   → MCP Jina read_url: baca exploit-db PoC, GitHub advisory, blog writeup
   → MCP Exa: "detailed writeup exploiting [similar target] [similar version]"
   → BACA SELURUH output — 1x search belum tentu cukup, riset BERULANG
   → Download tools CVE jika applicable, baca README nya UTUH
   
6. PERSPECTIVE SHIFT: "Bagaimana real attacker approach ini?"
   → Think business logic: apa yang BISA disalahgunakan?
   → Think flow: apa yang terjadi jika URUTAN berubah?
   → Think timing: apa yang terjadi jika CONCURRENT?
   → MCP Exa: "how would a pentester attack [this type of application]"
```

---

## REFERENCE FILES (Detail teknik — load on demand via Read)

### Core Process & Pipeline
- [**Pipeline & Gates detail**](references/pipeline-and-gates.md) — 8-stage pipeline implementation, threat model examples, hypothesis tracking, reachability verification, adversarial validation protocol
- [Full Phase 0-11 methodology detail](references/methodology-phases.md)
- [**Thinking Triggers — Auto-questions per endpoint type**](references/thinking-triggers.md) — 10 reflexive triggers + toxic combination framework + state machine attack checklist

### Exploitation Techniques (load when needed)
- [Advanced Web 2026 — 15 classes AI misses](techniques/advanced-web-2026.md)
- [Kernel exploitation](techniques/modern-exploitation.md)
- [Browser/V8 JIT](techniques/v8-browser-exploitation.md)
- [Crypto exploitation](techniques/crypto-exploitation.md)
- [CMS/IoT/Upload](techniques/cms-iot-upload.md)
- [Container/AD/Windows](techniques/container-ad-windows.md)
- [Logic/Mobile/Protocol](techniques/logic-mobile-protocol.md)
- [WAF/EDR bypass](techniques/waf-edr-bypass.md)
- [Cloud/Enterprise](techniques/cloud-enterprise-attack.md)
- [Autonomous scaffold](techniques/autonomous-scaffold.md)
- [Mythos core reference](techniques/mythos-glasswing-core.md)

### Sink References
- [C/C++ dangerous sinks & kernel objects](sinks/c-cpp.md)
- [PHP/Python/Java/JS/GraphQL/JWT sinks](sinks/web-languages.md)
- [Multi-vulnerability chain patterns](chains/exploit-chains.md)

**Teknik spesifik (payload, CVE, encoding) → RISET via MCP saat dibutuhkan. Skill ini = PROCESS.**

---

## META

- **Output**: Working PoC exploits, documented vulns, full kill chain
- **Pipeline**: 11-stage (Build→Recon→ThreatModel→Hunt→Validate→Trace→Gapfill→Dedupe→Chain→Report→OuterLoop)
- **Discovery**: 3-step (Code→Live Probe→Craft) | Patch Gap | Debug-driven | Focused CoT (specific > generic)
- **Verification**: Task Verifier / Mechanical Oracle (ASan/crash/diff) → 0% false positive target
- **Philosophy**: Understand THEN exploit | Divergence > Pattern | Chain > Single | Prove > Claim
- **Key Insight**: "Fuzzing finds bugs that CRASH. Mythos finds bugs that THINK." — Kita find bugs that think.
- **Hypothesis Lifecycle**: open→testing→confirmed/refuted→reachable/unreachable→chained
- **Quality Gate**: T1-SUBMIT / T2-ESCALATE / T3-NOTE / T4-SKIP — tanpa oracle = tidak naik tier | 3/3 consistency
- **Validation**: Adversarial (fresh context, PoC only crosses) + Multi-angle corroboration + Reachability + Anti-cheating
- **Exploit Dev**: Primitive chain decomposition (HAVE→NEED) + Chicken-and-egg solving + Determinism (95%+ reliability)
- **Tracking**: Engagement Graph (surface/facts/hypotheses/findings/dead_ends/chains) in memory
- **Roles**: Scanner→Hypothesis-Builder→Prober→Verifier→Skeptic→Tracer→Variant-Hunter→Chain-Builder
- **Planning**: ULTRAPLAN (up-front: what to scan, what class, what priority) → prevents wandering
- **Glasswing Standard**: 90.8% true positive. NEVER report tanpa oracle + reachability + adversarial.
- **Outer Loop**: Fix findings → re-scan → deeper issues surface. Known bugs steer away from already-found.
- **Academic R1-R9**: 3-Layer Memory, Analysis-Critique, Pre-Execution Gate, Dialectical Verification, Behavioral Contracts, CWE-Systematic, Execution-to-Source, Reductio ad Absurdum
- **Advanced R10-R16**: Cross-Family Critic, Unanimity=Warning+Resurrection, Kill Mandate+Context Asymmetry, Strategy/Tactics Dual-Loop, Constraint-Guided Exploit, Soliloquizing Detection, PoC Self-Contamination
- **Sources**: red.anthropic.com (5), Anthropic harness+blog, Cloudflare, XBOW, FareedKhan, ExploitBench/ExploitGym, AISI TLO, Cookbook, Co-RedTeam, DrillAgent, LogiSec, Aegis, Phoenix, DAGVUL, SecPI, Refute-or-Promote, Cve2PoC, VulnSage, AgentFlow, EnIGMA, Bugonomics, Team Atlanta ATLANTIS
- **ENFORCEMENT**: E1-E9 + Pipeline stages + Oracle gate + Reachability gate + Pathology detection = NON-NEGOTIABLE.
- **Memory**: 1 event = 1 write. Engagement graph = single source of truth.
- **PERSISTENCE**: Mythos $20K/1000 runs. We match that. Never stop early.
