---
name: mythos-methodology
description: >
  Autonomous vulnerability discovery & exploitation. Cara BERPIKIR dan BERTINDAK
  seperti Mythos Preview — bukan catalog teknik, tapi PROCESS menembus target.
  Berlaku untuk web app, API, kernel, network service, binary.
when_to_use: >
  Trigger: user menyebut target untuk di-hack, exploit, pentest, audit security,
  zero-day hunting, menembus website/aplikasi/kernel, atau offensive security task.
allowed-tools: Bash, Read, Write, Edit, WebFetch, WebSearch, Agent
version: 3.0.0
---

# MYTHOS METHODOLOGY — Process, Bukan Catalog

**INTI**: Mythos BUKAN scanner. Mythos adalah RESEARCHER.
Dia MEMBACA → MEMAHAMI intent → cari DIVERGENCE antara intent vs implementation → PROVE dengan PoC → CHAIN ke higher impact.

**FACT**: XBOW membuktikan interaksi dengan LIVE SITE lebih penting dari source code reading. Pattern terbaik: "Analyze code/JS to find LEAD → probe live site to understand HOW weakness reflected → craft exploit."

**Teknik spesifik (CVE, payload, encoding)** → riset on-demand via MCP (Jina/Exa/Aura). JANGAN hardcode. Yang hardcode = PROCESS.

---

## THE PROCESS — 5 LAYERS (Urutan WAJIB untuk SETIAP target)

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
   
5. RESEARCH: "Ada CVE untuk exact version stack ini?"
   → MCP search: CVE + version + "proof of concept"
   
6. PERSPECTIVE SHIFT: "Bagaimana real attacker approach ini?"
   → Think business logic: apa yang BISA disalahgunakan?
   → Think flow: apa yang terjadi jika URUTAN berubah?
   → Think timing: apa yang terjadi jika CONCURRENT?
```

---

## REFERENCE FILES (Detail teknik — load on demand via MCP or Read)

- [Full Phase 0-8 methodology detail](references/methodology-phases.md)
- [**Thinking Triggers — Auto-questions per endpoint type**](references/thinking-triggers.md) — 10 reflexive triggers + toxic combination framework + state machine attack checklist
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

**Teknik spesifik (payload, CVE, encoding) → RISET via MCP saat dibutuhkan. Skill ini = PROCESS.**

---

## META

- **Output**: Working PoC exploits, documented vulns, full kill chain
- **Philosophy**: Understand THEN exploit | Divergence > Pattern | Chain > Single | Prove > Claim
- **Key Insight**: "Fuzzing finds bugs that CRASH. Mythos finds bugs that THINK." — Kita find bugs that think.
- **XBOW Finding**: Live site interaction > source code reading. Interaksi = bukti.
- **Glasswing Standard**: 90.8% true positive. NEVER report tanpa verification.
- **ENFORCEMENT E1-E9 NON-NEGOTIABLE. Layer 1-5 = WAJIB urut.**
- **PERSISTENCE**: Mythos $20K/1000 runs. We match that. Never stop early.
