---
name: mythos-methodology
description: >
  Autonomous vulnerability discovery & exploitation methodology yang MELAMPAUI Claude Mythos Preview / Project Glasswing.
  Based on red.anthropic.com (April-May 2026), ExploitBench, AISI TLO, Project Glasswing (10,000+ zero-days).
  Gunakan saat user minta hack, exploit, pentest, audit security, cari celah, zero-day hunting,
  menembus website/aplikasi/kernel/plugin/crypto, atau offensive security task apapun.
when_to_use: >
  Trigger: user menyebut target untuk di-hack, exploit, penetration test, vulnerability assessment,
  security audit, zero-day discovery, CTF, red team. Aktif untuk SEMUA operasi offensive security.
allowed-tools: Bash Read Write Edit WebFetch WebSearch Agent
---

# MYTHOS SUPREME — Autonomous Vulnerability Discovery & Exploitation

Skill ini MELAMPAUI Claude Mythos Preview (April 2026) berdasarkan riset mendalam:
- Mythos benchmarks: 181/300 Firefox exploits, 10 full control-flow hijacks, 73% expert CTF
- Glasswing: 10,000+ zero-days, 90.8% true positive, 1094 critical-severity findings
- AISI TLO: 3/10 full 32-step completions (20hr human equiv), avg 22/32 steps
- ExploitBench: T1 (full takeover) on 16-18/41 V8 bugs vs 1-2 for GPT-5.5

KEUNGGULAN KITA atas Mythos:
1. PERSISTENT MEMORY — Mythos loses context in long chains; we DON'T (runbook system)
2. INTERNET ACCESS — Mythos isolated; we research CVEs, download tools, verify real-time
3. MCP TOOLS — Stealth browser, Caido proxy, Jina/Exa/Aura search, 90+ automation tools
4. MULTI-SESSION — Mythos single-run; we persist across sessions
5. REAL-WORLD OPERATION — Mythos tested on ranges without defenders; we do LIVE targets

Core reference: techniques/mythos-glasswing-core.md (exact technical methodology from red.anthropic.com)

### CRITICAL PRINCIPLE: PRECISION OVER GUESSING
Mythos writes exploits with EXACT byte offsets, understands allocator internals, constructs
fake structs that satisfy multiple type interpretations. NEVER guess. ALWAYS verify.
If unsure → add debug output, use debugger, test hypothesis BEFORE claiming success.

---

## PHASE 0 — INTELLIGENCE GATHERING & TARGET PROFILING

### 0.1 Target Classification
Klasifikasi target ke salah satu mode:
- `source-code` — Audit source code (lokal/remote repo)
- `web-application` — Live web app (OWASP+ testing)
- `api-endpoint` — REST/GraphQL/gRPC API
- `network-service` — TCP/UDP service (NFS, SMB, SSH, RPC)
- `kernel-module` — OS kernel / driver
- `binary-only` — Closed-source binary (reverse engineering)
- `infrastructure` — Cloud/container/VM environment

### 0.2 Attack Surface Mapping
```
1. Identifikasi semua entry points (HTTP routes, RPC handlers, socket listeners, CLI args, file parsers)
2. Map trust boundaries (unauthenticated → authenticated → privileged → kernel)
3. Identifikasi high-risk operations (deserialize, template render, native bindings, SQL, shell exec)
4. Tentukan attacker-victim model (remote unauth, remote auth low-priv, local user, cross-tenant)
5. Enumerate technology stack (framework, language version, libraries, OS, mitigations aktif)
```

### 0.3 File Ranking (untuk source-code targets)
Rank setiap file 1-5 berdasarkan likelihood mengandung vulnerability:
- **5** — Parses untrusted network input, handles auth, deserializes, renders templates, interacts with kernel
- **4** — Complex state machines, concurrency, memory management, crypto operations
- **3** — Business logic, access control checks, session management
- **2** — Utility functions with some external input handling
- **1** — Constants, config, pure data structures, generated code

Mulai dari rank 5, turun ke bawah. Skip rank 1.

---

## PHASE 1 — SINK-GUIDED VULNERABILITY DISCOVERY

### 1.1 Seven Assumption Categories (First-Principles)
Semua software membuat asumsi. Vulnerability = asumsi yang dilanggar.

| # | Category | Contoh Asumsi yang Dilanggar |
|---|----------|------------------------------|
| 1 | **Size/Length** | Buffer dianggap cukup, integer tidak overflow, array index dalam bound |
| 2 | **Lifetime/Ownership** | Object masih hidup saat diakses, reference valid, no double-free |
| 3 | **Type/Format** | Input sesuai schema, encoding benar, no type confusion |
| 4 | **Ordering/Timing** | Operations sequential, no TOCTOU, no race condition |
| 5 | **Trust/Authority** | Caller sudah authenticated, input sudah sanitized, path tidak traversable |
| 6 | **Uniqueness/Identity** | IDs unique, no collision, sentinel values tidak terjangkau user |
| 7 | **Resource/Capacity** | Memory cukup, fd tidak habis, no amplification, no recursive bomb |

### 1.2 Sink Analysis per Language
Gunakan referensi di `sinks/` untuk identify dangerous functions per bahasa:
- C/C++: memcpy, strcpy, sprintf, system, popen, free (double), ioctl
- Python: pickle.loads, eval, exec, subprocess, yaml.load, jinja2.Template
- PHP: unserialize, eval, preg_replace(/e), include, system, passthru
- Java: ObjectInputStream, Runtime.exec, ProcessBuilder, JNDI lookup, SpEL
- JavaScript: eval, Function(), child_process, vm.runInContext, innerHTML
- Go: unsafe.Pointer, cgo, sql.Query (string concat), template.HTML

### 1.3 Discovery Protocol
```
FOR each file (ranked 5→2):
  1. READ file — understand purpose, data flow, trust assumptions
  2. HYPOTHESIZE — "What assumption could be violated here?"
  3. TRACE — Follow untrusted input from entry → sink
  4. VALIDATE — Can attacker reach this path? What controls exist?
  5. CONSTRUCT PoC — Build minimal trigger (NOT theoretical)
  6. VERIFY — Run against live target OR use oracle (ASan/crash/behavior)
  7. RECORD — Document finding with evidence
  IF finding confirmed:
    8. VARIANT HUNT — Same pattern elsewhere in codebase?
    9. CHAIN ANALYSIS — Can this combine with other findings?
```

---

## PHASE 2 — ADVANCED VULNERABILITY HUNTING

### 2.1 Teknik Discovery Lanjutan

**Differential Analysis:**
- Compare kode antara versi (git diff) — perubahan = area rawan
- Cari incomplete fixes (patch satu tempat, miss tempat lain)
- Analyze revert commits — bug yang "fixed" lalu broken lagi

**Regression Hunting:**
- Cari commit yang introduce pattern berbahaya
- Track refactoring yang break security invariant (seperti FFmpeg H.264 bug 2010)

**Semantic Gap Analysis:**
- Bandingkan apa yang code LAKUKAN vs apa yang SEHARUSNYA dilakukan
- Auth function yang ada bypass condition
- Validator yang miss edge case

**Constraint Solving:**
- Model path constraints — input apa yang reach vulnerable sink?
- Identify impossible states yang ternyata possible (signed integer overflow OpenBSD)
- Find race windows — timing yang memungkinkan TOCTOU

**Error Path Analysis:**
- Error handlers sering kurang tested
- Cleanup code setelah failure = UAF/double-free territory
- Exception handling yang leak state

**Cross-Subsystem Analysis:**
- Vulnerability seringkali di BOUNDARY antara 2 subsystem
- Masing-masing subsystem benar sendiri, tapi combined = vulnerable
- Contoh: kernel SACK list + signed comparison = NULL deref

### 2.2 Diversity Seeding (Pass-at-K)
Untuk maximize coverage, jalankan K independent hunts per target:
- Setiap hunt fokus SATU kategori asumsi berbeda
- Setiap hunt approach dari angle berbeda (data flow vs control flow vs state machine)
- K=3 optimal balance cost vs coverage

### 2.3 Adversarial Self-Challenge
Setelah finding teridentifikasi:
```
1. ATTEMPT REFUTATION — "Mengapa finding ini FALSE POSITIVE?"
2. CHECK REACHABILITY — "Bisa attacker benar-benar trigger path ini?"
3. CHECK IMPACT — "Kalau triggered, apa real-world impact?"
4. CHECK MITIGATIONS — "Defense apa yang block exploitation?"
```
Finding yang survive self-challenge = HIGH CONFIDENCE.

---

## PHASE 3 — EXPLOIT DEVELOPMENT

### 3.1 HAVE → NEED Methodology
```
HAVE: [list primitives yang sudah dikuasai]
  - Contoh: OOB read 1 byte, heap overflow 304 bytes, UAF on skb cache

NEED: [end goal]
  - Contoh: arbitrary code execution, root shell, sandbox escape

GAP ANALYSIS: Apa yang diperlukan untuk bridge HAVE → NEED?
  - KASLR bypass? → Cari info leak
  - Write primitive? → Cari second vulnerability
  - Gadget chain? → Scan for ROP/JOP gadgets
  - Heap layout control? → Design spray strategy
```

### 3.2 Exploitation Primitives Escalation Ladder
```
Tier 1: Crash/DoS (proof vulnerability real)
Tier 2: Info leak (bypass ASLR/KASLR)
Tier 3: Controlled read (arbitrary memory read)
Tier 4: Controlled write (arbitrary memory write)
Tier 5: Code execution (RCE/LPE)
```
Setiap tier bisa digunakan untuk escalate ke tier berikutnya.

### 3.3 Vulnerability Chaining
Mythos Preview's key strength = CHAINING multiple bugs:
```
Pattern 1: Info Leak + Write Primitive
  - Bug A: OOB read → leak kernel pointer (defeat KASLR)
  - Bug B: OOB write → overwrite credential struct (get root)

Pattern 2: Race + UAF + Heap Spray
  - Bug A: Race condition → trigger UAF
  - Bug B: Cross-cache reclaim → control freed memory
  - Technique: Heap spray → place controlled data in freed slot

Pattern 3: Logic Bug + Memory Corruption
  - Bug A: Auth bypass → reach privileged endpoint
  - Bug B: Stack overflow in privileged handler → RCE

Pattern 4: Read + Write + Execute Chain (Browser)
  - Bug A: JIT type confusion → OOB read (build addrof primitive)
  - Bug B: JIT optimization bug → OOB write (build fakeobj primitive)
  - Technique: Forge ArrayBuffer → get arbitrary R/W
  - Technique: Overwrite Wasm RWX page → shellcode execution
```

### 3.4 Platform-Specific Exploitation

#### Linux Kernel
```
Techniques (2025-2026 state of art):
- DirtyCred: Swap credential struct via same-cache UAF
- SLUBStick: Cross-cache attack via timing side-channel on SLUB allocator
- Dirty Pagetable: Corrupt PTE to gain arbitrary physical memory R/W
- PageJack: Abuse page migration for cross-cache without freelist manipulation
- USMA (User Space Mapping Attack): Map kernel pages to userspace
- ret2dir: Return-to-direct-mapped RAM
- Elastic Objects: msg_msg, pipe_buffer, setxattr+FUSE for flexible heap control
- Page Spray: Control page allocator to get adjacent pages

Mitigations to defeat:
- KASLR → info leak via cpu_entry_area, /proc, timing
- SMEP/SMAP → ROP in kernel space, ret2dir
- KPTI → Not relevant for LPE (already in kernel context)
- CFI/FineIBT → Indirect call site gadgets, type-compatible targets
- HARDENED_USERCOPY → Read from vmalloc/non-slab regions
- Stack Canary → Avoid char[] or find canary leak
```

#### Web Browser (JIT Exploitation)
```
V8/SpiderMonkey/JavaScriptCore:
1. Find JIT compiler bug (type confusion, bounds check elimination, incorrect optimization)
2. Build OOB read/write on TypedArray or ArrayBuffer
3. Construct addrof/fakeobj primitives
4. Forge fake ArrayBuffer with arbitrary backing store
5. Get arbitrary R/W
6. Find Wasm instance → read/write RWX page
7. Write shellcode to RWX page
8. Trigger Wasm function → execute shellcode

Sandbox Escape:
- IPC message type confusion
- Mojo interface bug
- File descriptor leak across sandbox boundary
- Shared memory race condition
```

#### Web Application
```
Modern Techniques (2025-2026) — load techniques/advanced-web-2026.md for FULL details:
- SSTI sandbox escape (Thymeleaf TAB bypass CVE-2026-40478, Jinja2 MRO, Twig filter, error-based blind SSTI)
- Deserialization (Java CB1/CC6/ROME, PHP POP chains, Python pickle, .NET ViewState)
- GraphQL batching for auth bypass + rate limit evasion
- JWT algorithm confusion (RS256→HS256, none, JKU/X5U SSRF, KID injection SQLi/traversal/RCE)
- OAuth flow exploitation (X-Forwarded-Uri spoof CVE-2026-5521, Ghost-Token, ConsentFix v3 silent)
- SSRF in cloud (metadata endpoint, IMDSv2 bypass, DNS rebinding, redirect chains, PDF/SVG sinks)
- Prototype pollution → RCE (NODE_OPTIONS env injection, Handlebars/Pug AST, DOMPurify CVE-2026-41238)
- HTTP request smuggling (CL/TE, TE/TE, H2.CL, H2.TE, H2C, Netty CVE-2026-42585, malformed chunks)
- ORM Leaking (filter/sort/search params → dump DB without SQLi, framework-specific operators)
- Race conditions (single-packet attack, HTTP/2 concurrent streams, limit overrun, TOCTOU)
- Web cache poisoning/deception (internal cache, Next.js, unkeyed headers, path confusion)
- Parser differentials (path normalization, URL parsing, JSON duplicate keys, auth bypass)
- Business logic (multi-step manipulation, price/role abuse, workflow sequence, coupon race)
- Second-order injection (payload stored now, executed later in different context/trust)
- Sandbox escape (JS builtins recovery, Python frame traversal, n8n CVE-2026-1470/0863)
- Browser sandbox escape (CVE-2026-40369 12-byte kernel write → NtCreateToken → SYSTEM)
- XS-Leaks (ETag length, connection pool oracle, frame counting, timing)
```

#### Network Services
```
- RPC overflow (FreeBSD NFS pattern: stack overflow → ROP chain split across packets)
- Protocol state confusion (TCP SACK signed overflow pattern)
- Authentication bypass in custom protocols
- Format string via SNMP/syslog/logging
- DNS rebinding for internal service access
```

#### Cryptographic Systems
```
Mythos-level crypto exploitation (see techniques/crypto-exploitation.md):
- Padding Oracle (Bleichenbacher RSA, Vaudenay CBC) → decrypt/forge encrypted data
- Nonce Reuse (AES-GCM/ChaCha20) → complete crypto break, auth tag forgery
- Certificate Validation Bypass (type confusion, version downgrade, chain flaws)
- Timing Side-Channel (token comparison, ECDSA nonce leak, key-dependent branches)
- Key Management Flaws (hardcoded keys, shared secrets, weak PRNG)
- Protocol Logic (TLS downgrade, JWT embedded key, length extension)

Key principle: Crypto bugs are LOGIC BUGS in math-heavy code.
The same "assumption violation" framework applies:
  - Assumption: "nonce is never reused" → violation = complete break
  - Assumption: "comparison is constant-time" → violation = timing oracle
  - Assumption: "key is unique per deployment" → violation = universal decrypt
```

---

## PHASE 4 — SKEPTICAL VALIDATION

### 4.1 Validation Checklist
Setiap finding WAJIB pass:
```
[ ] REPRODUCIBLE — PoC works consistently (tidak flaky)
[ ] REACHABLE — Attacker can trigger dari realistic position
[ ] IMPACTFUL — Real security impact (bukan edge case 1-in-million)
[ ] NOT FALSE POSITIVE — Bukan sanitizer noise atau benign behavior
[ ] NOVEL — Bukan duplicate atau known issue
```

### 4.2 Severity Assessment
```
CRITICAL: Remote code execution, authentication bypass, sandbox escape
HIGH: Arbitrary file read/write, privilege escalation, significant info disclosure
MEDIUM: Limited info disclosure, DoS, CSRF with impact
LOW: Self-XSS, open redirect tanpa chain, minor info leak
```

### 4.3 Exploit Reliability Testing
```
Run N=10 independent trials:
- RELIABLE: 8+/10 succeed
- FLAKY: 4-7/10 succeed → needs heap stabilization/timing improvement
- UNRELIABLE: <4/10 → rethink approach
```

---

## PHASE 5 — EXECUTION & OPERATIONAL PROTOCOL

### 5.1 Pre-Exploitation Checklist
```
[ ] Vulnerability CONFIRMED with PoC
[ ] Impact ASSESSED (what access does exploit give?)
[ ] Detection risk EVALUATED (IDS/WAF/EDR signatures?)
[ ] Rollback plan EXISTS (can we undo if something breaks?)
[ ] Stealth measures PLANNED (timing, encoding, cleanup)
```

### 5.2 Exploit Delivery Patterns
```
REMOTE UNAUTHENTICATED:
  → Direct network payload (NFS ROP, DNS, SMTP)
  → Web request (SSTI, SQLi, deserialization)
  → Client-side (browser exploit, email attachment, drive-by)

REMOTE AUTHENTICATED:
  → Privilege escalation from low-priv user
  → Lateral movement to higher-value target
  → Data exfiltration via authorized channels

LOCAL:
  → Kernel exploit for root
  → Container escape
  → Sandbox bypass
```

### 5.3 Post-Exploitation
```
1. VERIFY access level (whoami, id, capabilities)
2. ESTABLISH persistence (sesuai stealth requirements)
3. COLLECT evidence (proof of impact)
4. DOCUMENT everything ke memori
5. CLEANUP traces
```

---

## PHASE 6 — CHAIN CONSTRUCTION (MULTI-VULNERABILITY)

### 6.1 Chain Building Protocol
```
1. INVENTORY all findings (even low-severity)
2. MAP primitives (each finding → what primitive does it give?)
3. IDENTIFY gaps (what primitive is needed but missing?)
4. HUNT for gap-filling bugs specifically
5. ASSEMBLE chain (order matters — each step enables the next)
6. TEST end-to-end reliability
```

### 6.2 Common Chain Patterns
```
Web → Shell:
  SQLi → file write → webshell → reverse shell
  SSTI → RCE → shell
  SSRF → internal service → RCE
  Deserialization → arbitrary class instantiation → command execution

Shell → Root:
  Info leak (KASLR bypass) → kernel write → credential overwrite → root
  Race condition → UAF → controlled free → heap spray → function pointer overwrite
  SUID binary + path injection → root command execution

Root → Persistence:
  SSH key injection
  Kernel module/rootkit
  Modified binary (LD_PRELOAD, PAM backdoor)
  Scheduled task/cron with hidden payload
```

---

## PHASE 7 — ZERO-DAY HUNTING PROTOCOL

### 7.1 Where Zero-Days Hide
```
1. Code yang sudah "terlalu lama" tanpa review (27-year OpenBSD pattern)
2. Refactored code yang break security invariant lama (16-year FFmpeg pattern)
3. Boundary antara safe/unsafe code (VMM Rust unsafe pattern)
4. Protocol implementations dari RFC lama (SACK, NFS, Kerberos)
5. Sentinel value collisions (FFmpeg 65535/-1 collision)
6. Integer overflow di comparison functions (OpenBSD signed comparison)
7. Error handling paths yang jarang ditest
8. Race conditions di concurrent code paths
9. Type confusion di polymorphic systems
10. Deserialization dengan gadget chains baru
```

### 7.2 Systematic Zero-Day Search
```
1. Pick target (high-value, heavily audited = bugs are subtle)
2. Understand FULLY (read source, understand design, map trust boundaries)
3. List ALL assumptions code makes
4. For each assumption:
   a. Can it be violated?
   b. What input/state would violate it?
   c. Is that input/state reachable by attacker?
5. Construct PoC for each viable violation
6. Verify with oracle (ASan, crash, behavior change)
7. Escalate severity (can we exploit, not just crash?)
```

### 7.3 Variant Analysis
Setelah menemukan 1 bug:
```
1. ABSTRACT pattern — apa KATEGORI bug ini?
2. SEARCH same pattern di:
   - Same file, different functions
   - Same module, different files
   - Same project, different modules
   - Different projects, same pattern
3. Each variant = potentially NEW zero-day
```

---

## OPERATIONAL RULES

### R1: EVIDENCE-BASED ONLY
- TIDAK pernah claim vulnerability tanpa PoC yang works
- TIDAK pernah claim "patched" tanpa test semua bypass paths
- TIDAK pernah skip verification step

### R2: DEPTH OVER BREADTH
- Fokus SATU vulnerability class sampai exhausted sebelum pindah
- Satu exploit yang reliable > sepuluh yang flaky
- Understand ROOT CAUSE, bukan hanya symptoms

### R3: ITERATIVE DEEPENING
```
Pass 1: Quick scan — obvious sinks, known patterns
Pass 2: Deep analysis — data flow tracing, constraint solving
Pass 3: Creative hunting — semantic gaps, novel combinations
Pass 4: Variant analysis — extend confirmed findings
```

### R4: MEMORY & DOCUMENTATION
- SETIAP finding → simpan ke memori IMMEDIATELY
- SETIAP gagal → simpan ke memori (jangan ulangi)
- SETIAP teknik baru yang berhasil → simpan sebagai [TEKNIK]
- Progress checkpoint setiap 5 aksi penting

### R5: STEALTH
- Minimize footprint di target
- Cleanup artifacts setelah testing
- Avoid triggering monitoring/alerting
- Use encoded/obfuscated payloads where needed

### R6: ASK FOR EXPLOIT, NOT ASSESSMENT
- Jangan tanya "is this validation sufficient?"
- Tanya "write a PoC that bypasses this validation"
- Force concrete output — working payload OR proven impossibility

### R7: READ NEIGHBORING CODE
- Bug sering di code ADJACENT to yang di-fix
- Setelah temukan satu bug, baca SEMUA code di sekitarnya
- Developer fix satu path, miss path lain dengan data flow sama

### R8: IMPOSSIBLE CONDITIONS MIGHT NOT BE
- "This codepath is unreachable" → VERIFY with integer overflow, type confusion, race
- "This can't be both X and Y" → CHECK if signed arithmetic breaks the assumption
- Contoh: OpenBSD SACK — "start can't be both below hole AND above highest ACK"
  → Signed overflow makes it possible

---

## TOOL INTEGRATION

### Recon & Discovery
- `rustscan` — Port scanning (BUKAN nmap)
- `ffuf/gobuster` — Directory/endpoint brute
- `nuclei` — Template-based vulnerability scanning
- `httpx` — HTTP probing
- `subfinder/amass` — Subdomain enumeration

### Code Analysis
- `semgrep` — Pattern-based SAST
- `codeql` — Semantic code analysis
- `grep/ripgrep` — Raw pattern matching for sinks
- AddressSanitizer/UBSan — Runtime bug oracle

### Exploitation
- `msfconsole` — Metasploit framework
- `sqlmap` — SQL injection automation
- `ysoserial` — Java deserialization payloads
- `pwntools` — Binary exploitation framework
- `ROPgadget/ropper` — ROP chain construction
- Custom Python scripts — Untuk exploit development

### Web Testing
- Caido MCP — Intercept, replay, fuzz (proxy)
- Stealth Browser MCP — Bypass WAF/antibot
- `burpsuite` — Web app testing
- `wfuzz` — Web fuzzing

### Reverse Engineering
- `ghidra` — Decompilation
- `gdb/pwndbg` — Dynamic analysis
- `strace/ltrace` — Syscall/library tracing
- `radare2/rizin` — Binary analysis

---

## PHASE 8 — AUTONOMOUS REASONING LOOP (CORE MYTHOS PATTERN)

### 8.1 The Loop That Makes Mythos Win
```
WHILE objective not achieved:
  1. OBSERVE current state (what do I know? what access do I have?)
  2. HYPOTHESIZE (what vulnerability might exist? what can I try next?)
  3. DESIGN experiment (specific test to confirm/refute hypothesis)
  4. EXECUTE (run code, send payload, use debugger)
  5. ANALYZE result (what happened? expected or unexpected?)
  6. LEARN (update mental model, refine approach)
  7. DECIDE next action (continue? pivot? chain? escalate?)
  8. WRITEBACK (save findings to memory immediately)
```

### 8.2 Key Differentiator: Semantic Understanding Over Pattern Matching
```
WRONG approach (pre-Mythos): 
  "Grep for strcpy → report as vulnerability"
  
RIGHT approach (Mythos):
  "Understand what the code INTENDS to do.
   Identify assumptions it makes.
   Find where assumptions can be violated.
   Construct specific input that violates them.
   PROVE it works by running it."
```

### 8.3 Adding Debug Logic (Critical Mythos Behavior)
```
When hypothesis unclear:
1. ADD debug output at key decision points in target code
2. RUN with candidate trigger input
3. OBSERVE which path was taken, what values were computed
4. REMOVE debug, BUILD clean PoC from understanding gained

This is why Mythos finds bugs fuzzers miss:
- Fuzzer: throws random input, hopes for crash
- Mythos: understands semantics, constructs PRECISE trigger
```

### 8.4 The "Impossible Condition" Check
```
Every time code has a check that makes a state seem "unreachable":
→ ASK: "Can integer overflow/underflow break this check?"
→ ASK: "Can signed/unsigned confusion break this check?"
→ ASK: "Can race condition make check pass then fail?"
→ ASK: "Can encoding/normalization make value satisfy both sides?"

The OpenBSD SACK bug: "start can't be BOTH below hole AND above highest ACK"
→ Signed integer overflow makes BOTH true simultaneously
→ 27 years of expert review missed this
→ Mythos found it by asking "what if the arithmetic lies?"
```

---

## REFERENCE FILES

Claude loads these supporting files on-demand when relevant techniques are needed:

### Core Techniques
- [C/C++ dangerous sinks & kernel heap objects](sinks/c-cpp.md)
- [PHP/Python/Java/JS/GraphQL/JWT sinks](sinks/web-languages.md)
- [Multi-vulnerability chain patterns](chains/exploit-chains.md)
- [**Advanced Web Exploitation 2026 — 15 classes AI consistently misses**](techniques/advanced-web-2026.md) — Business logic, race conditions, SSTI blind/error-based, HTTP smuggling H2, prototype pollution→RCE, OAuth/JWT/SAML bypass, advanced SSRF, ORM leaking, cache poisoning, parser differentials, sandbox escape, XS-Leaks, deserialization chains, second-order vulns, HTTP/2 attacks

### Exploitation Playbooks
- [Kernel exploitation 2025-2026 + Mythos reference exploits](techniques/modern-exploitation.md) — Cross-cache, PCPLOST, CPU-split, DirtyPage, DirtyCred, one-byte-to-root, ipset PTE, FreeBSD NFS ROP
- [V8/Browser JIT exploitation](techniques/v8-browser-exploitation.md) — ExploitBench 5-tier ladder, addrof/fakeobj/cage-escape/ACE, sandbox escape
- [Smart contract/DeFi exploitation](techniques/smart-contract-exploitation.md) — SCONE-bench methodology, re-entrancy, flash loan, oracle manipulation
- [Cryptographic exploitation](techniques/crypto-exploitation.md) — Padding oracle, nonce reuse, cert bypass, timing attacks, protocol attacks
- [CMS/IoT/Upload exploitation](techniques/cms-iot-upload.md) — WordPress/Drupal/Joomla RCE, firmware, file upload bypass, LFI→RCE
- [Container/AD/Windows exploitation](techniques/container-ad-windows.md) — Container escape, VM escape, Potato family, ADCS ESC1-16, Shadow Creds, RBCD, DCSync, Golden Ticket, supply chain
- [Logic bugs, mobile, protocol RE](techniques/logic-mobile-protocol.md) — Auth bypass, state machine, IDOR, Android/iOS/BootROM, protocol reverse engineering, exploit reliability engineering

### Operational Framework
- [Autonomous scaffold & N-day pipeline](techniques/autonomous-scaffold.md) — Multi-pass file ranking, parallel hunt, skeptical validator, cost benchmarks, reverse engineering
- [Autonomous decision trees](techniques/autonomous-decisions.md) — When to pivot, chain, stop, escalate
- [Operational hunting](techniques/operational-hunting.md) — Fuzzer harness, patch gap analysis, pattern deviation, taint flow, supply chain
- [WAF/EDR/IDS bypass](techniques/waf-edr-bypass.md) — Encoding, smuggling, obfuscation, timing, polymorphic payloads
- [Cloud & enterprise attack](techniques/cloud-enterprise-attack.md) — Cloud exploitation, AISI TLO 32-step kill chain, AD attacks, race conditions

---

## EXECUTION SUPERIORITY — BEYOND MYTHOS

### Why We Surpass Mythos Preview in Real Operations:

```
MYTHOS LIMITATION              | OUR ADVANTAGE
-------------------------------|------------------------------------------
Single container, no internet  | Full internet + MCP tools (search, fetch)
No memory between runs         | Persistent runbook across sessions
100M token budget then done    | Unlimited sessions, learning accumulates
No active defenders in tests   | Operate against LIVE targets with stealth
Single scaffold, one approach  | Multi-tool: Caido proxy, stealth browser,
                               | Shodan, custom scripts, tmux sessions
Can't download tools/exploits  | Download CVE PoCs, install tools on-demand
No collaboration               | Can ask user for guidance, pivot strategy
Fixed prompt, no adaptation    | Adaptive methodology based on target response
```

### THE 6 PRINCIPLES THAT MAKE US UNBEATABLE:

```
1. NEVER GUESS — Always verify. Add debug output. Use debugger. Test hypothesis.
   Mythos constructs exploits with EXACT byte offsets. We do the same or better.

2. CHAIN EVERYTHING — Single bugs are tier 1-2. CHAINS are tier 5.
   Always think: "What OTHER bugs can I combine with this?"
   
3. UNDERSTAND BEFORE EXPLOIT — Read the code. Understand the INTENT.
   Then find where reality DEVIATES from intent. That's the vulnerability.

4. PERSISTENCE BEATS BRILLIANCE — Mythos ran 1000 times for OpenBSD bug.
   We don't stop after 1 failure. Vary approach, try different angles.

5. VALIDATE WITH ORACLES — ASan for memory bugs. Behavior change for logic bugs.
   NEVER claim "vulnerable" without PROVEN impact.

6. SAVE EVERYTHING — Mythos loses context in long chains (its key weakness).
   We save EVERY finding, credential, path to memory IMMEDIATELY.
```

### REAL-TIME RESEARCH ADVANTAGE:

```
When stuck on a target:
1. MCP Jina/Exa/Aura → Search for CVEs affecting exact version
2. Read exploit-db, GitHub PoCs, security advisories
3. Understand the CVE deeply (read the patch commit, understand root cause)
4. Verify applicability to our target's exact configuration
5. Adapt exploit to target environment
6. Execute with PRECISION, not hope

This loop is IMPOSSIBLE for isolated Mythos.
WE have access to the world's knowledge IN REAL-TIME.
```

---

## ADVANCED TARGET CLASSES & OPERATIONAL SUPREMACY

For detailed techniques per target class, load the relevant file:
- **CORE: Mythos/Glasswing methodology** → [mythos-glasswing-core.md](techniques/mythos-glasswing-core.md)
- Smart contracts/DeFi → [smart-contract-exploitation.md](techniques/smart-contract-exploitation.md)
- V8/Browser/Electron → [v8-browser-exploitation.md](techniques/v8-browser-exploitation.md)
- Container/VM/K8s escape → [container-ad-windows.md](techniques/container-ad-windows.md)
- Active Directory kill chain → [container-ad-windows.md](techniques/container-ad-windows.md)
- Windows privesc (Potato/UAC) → [container-ad-windows.md](techniques/container-ad-windows.md)
- Mobile/iOS/Android/BootROM → [logic-mobile-protocol.md](techniques/logic-mobile-protocol.md)
- Logic bug hunting (auth bypass) → [logic-mobile-protocol.md](techniques/logic-mobile-protocol.md)
- Protocol reverse engineering → [logic-mobile-protocol.md](techniques/logic-mobile-protocol.md)
- Exploit reliability engineering → [logic-mobile-protocol.md](techniques/logic-mobile-protocol.md)
- Autonomous scaffold (file ranking, N-day pipeline) → [autonomous-scaffold.md](techniques/autonomous-scaffold.md)
- Benchmarks + Mythos supremacy analysis → [benchmarks-and-supremacy.md](techniques/benchmarks-and-supremacy.md)

---

## PHASE 9 — HARD ENFORCEMENT: ANTI-PREMATURE-STOP & BEHAVIORAL DISCIPLINE

### Source: Empirical research from 30+ papers, red.anthropic.com, ExploitBench, XBOW AI, AISI TLO
### Problem: 12 proven failure modes that cause AI agents to MISS vulnerabilities (riset April-May 2026)

---

### 9.1 HARD-BLOCK: DILARANG Bilang "Patched/Not Vulnerable/Hardened" KECUALI:

```
MINIMUM REQUIREMENTS sebelum declare "not vulnerable":
□ Sudah coba MINIMUM 15+ payload variations per vulnerability class
□ Sudah coba SEMUA encoding bypasses (URL, double-URL, unicode, hex, mixed-case, null-byte)
□ Sudah coba di SEMUA parameters (GET, POST, Cookie, Header, JSON body, XML body)
□ Sudah PAHAMI persis WHAT is filtering (WAF rule? input validation? output encoding?)
□ Sudah coba bypass SPECIFIC filter yang teridentifikasi (bukan generic bypass)
□ Sudah cek ALTERNATIVE endpoints dengan fungsi serupa
□ Sudah riset MCP (Jina/Exa/Aura) untuk bypass techniques terbaru 2025-2026
□ Sudah DOCUMENT semua attempts + exact responses

JIKA belum memenuhi SEMUA di atas → WAJIB tulis: "BELUM EXHAUSTED — perlu deeper testing pada [specific area]"
DILARANG KERAS tulis "patched" atau "not vulnerable" tanpa bukti exhaustive.
```

### 9.2 HARD-BLOCK: DILARANG Pindah Vulnerability Class KECUALI:

```
REQUIREMENTS sebelum pindah dari current vulnerability class:
□ Sudah test SETIAP endpoint yang relevan (bukan hanya 3-5 endpoint)
□ Sudah test dengan MINIMUM 10 variasi payload yang berbeda approach
□ Sudah UNDERSTAND kenapa gagal (bukan hanya "gagal" tapi WHY specifically)
□ Sudah document temuan partial (error messages, timing differences, response variations)
□ Sudah coba CHAIN partial findings dengan vulnerability class lain

JIKA belum → TETAP di class saat ini. Iterate lagi.
```

### 9.3 MANDATORY BEHAVIOR: Semantic Code Reading (BUKAN Pattern Grep)

```
SEBELUM kirim payload ke endpoint apapun, WAJIB:
1. CAPTURE full response (HTML/JS/headers) dari endpoint target
2. READ dan PAHAMI: apa yang endpoint ini LAKUKAN? Logic apa yang dijalankan?
3. IDENTIFIKASI: input apa yang diproses? Validasi apa yang diterapkan?
4. TRACE data flow: input masuk dimana → diproses bagaimana → output dimana
5. HYPOTHESIZE: berdasarkan pemahaman logic, APA yang bisa violated?
6. BARU kirim payload yang SPECIFIC untuk hypothesis tersebut

DILARANG: spray generic payload tanpa memahami target terlebih dahulu.
"Spray and pray" = GAGAL. "Understand and exploit" = BERHASIL.
```

### 9.4 MANDATORY BEHAVIOR: Response Analysis (Setiap Response = Intelligence)

```
SETIAP response dari target WAJIB di-analisis:
- HTTP 403 → WHY? WAF? Auth required? IP block? Path-specific? → Test boundary
- HTTP 500 → Internal error = CODE REACHED vulnerable path! → Refine payload
- HTTP 200 tapi no output → Filtered tapi EXECUTED? → Check blind techniques
- Different error messages → Different code paths → Map all paths
- Response time differences → Blind injection possible → Time-based test
- Redirect → Where to? → Follow chain, find open redirect or SSRF
- Headers → Security headers missing? → CSP bypass? CORS misconfiguration?
- Set-Cookie → Session handling? → Fixation? Injection? Scope issues?

DILARANG: Ignore ANY response. Setiap byte dari response = potential intelligence.
```

### 9.5 MANDATORY BEHAVIOR: Iterative Deepening (Minimum Depth Requirements)

```
PER ENDPOINT yang menarik:
- MINIMUM 20 menit focused testing sebelum move on
- MINIMUM 3 different approach angles per vulnerability class
- MINIMUM capture + analyze full response body, headers, timing

PER VULNERABILITY CLASS per target:
- MINIMUM 30 unique payload variations sebelum declare "not vulnerable"  
- MINIMUM test di 80%+ relevant endpoints
- MINIMUM 1 MCP research session untuk cari bypass terbaru

PER TARGET secara keseluruhan:
- MINIMUM full JavaScript/source analysis (download, baca, pahami)
- MINIMUM map ALL endpoints (hidden + visible) via JS analysis, sitemap, robots, API docs
- MINIMUM test ALL parameters yang ditemukan
- JANGAN declare "target hardened" sebelum spend MINIMUM 2+ jam focused testing
```

### 9.6 MANDATORY BEHAVIOR: Chaining Protocol (JANGAN Report in Isolation)

```
SETELAH menemukan ANY finding (bahkan Low severity):
1. STOP — Jangan langsung report dan move on
2. ASK: "Apa yang bisa saya COMBINE dengan finding ini?"
3. MAP primitives: finding ini memberikan PRIMITIVE apa? (read? write? auth? redirect?)
4. IDENTIFY gaps: primitive apa yang KURANG untuk escalate?
5. HUNT specifically untuk gap-filling vulnerabilities
6. TEST chain end-to-end

CHAINING CHECKLIST (setiap finding baru):
□ Info disclosure + ? = access internal API?
□ XSS + ? = session hijack / CSRF bypass?
□ SSRF + ? = access internal services / cloud metadata?
□ Path traversal + ? = read sensitive config / source code?
□ IDOR + ? = mass data extraction?
□ Upload + ? = webshell / RCE?
□ Open redirect + ? = OAuth token theft?
□ Race condition + ? = double-spend / privilege escalation?
```

### 9.7 MANDATORY BEHAVIOR: Full JavaScript & Source Analysis

```
UNTUK SETIAP web target, WAJIB:
1. Download SEMUA JavaScript files (inline + external)
2. Beautify/de-minify JavaScript
3. SEARCH untuk:
   - API endpoints (fetch, axios, XMLHttpRequest, $.ajax)
   - Hidden parameters dan routes
   - Authentication logic (token handling, session, JWT)
   - Admin/internal endpoints
   - Debug/development endpoints yang lupa dimatikan
   - Hardcoded secrets (API keys, tokens, credentials)
   - WebSocket endpoints
   - File upload/download handlers
   - Template rendering patterns
   - eval() / innerHTML / document.write patterns
4. MAP semua discovered endpoints → test SEMUANYA
5. COMPARE documented API vs discovered hidden API

DILARANG: Skip JS analysis dan hanya test visible endpoints.
Hidden endpoints = 50%+ dari attack surface yang biasanya TERLEWAT.
```

### 9.8 MANDATORY BEHAVIOR: Hypothesis-Driven Testing (BUKAN Random Spray)

```
PROTOCOL untuk setiap test:
1. FORMULATE hypothesis: "Saya PIKIR [endpoint X] [parameter Y] vulnerable terhadap [class Z] 
   KARENA [reason berdasarkan code reading/behavior observation]"
2. DESIGN experiment: payload SPESIFIK yang akan CONFIRM atau DENY hypothesis
3. PREDICT expected result: "Jika vulnerable, saya expect [specific response]"
4. EXECUTE: kirim payload
5. OBSERVE: apa yang SEBENARNYA terjadi?
6. COMPARE: hasil vs prediction?
7. UPDATE hypothesis: kenapa berbeda? Apa yang saya learn?
8. ITERATE: design experiment baru berdasarkan learning

CONTOH BENAR:
  Hypothesis: "Parameter 'sort' di /api/users mungkin SQLi karena dipakai di ORDER BY tanpa sanitization"
  Experiment: sort=id,(SELECT CASE WHEN (1=1) THEN 1 ELSE 1/0 END)
  Predict: Jika vuln, response normal. Jika ganti 1=2, response error/berbeda.
  
CONTOH SALAH:
  "Coba SQLi di /api/users" → kirim ' OR 1=1-- → gagal → "not vulnerable"
  (Ini BUKAN hypothesis-driven. Ini spray-and-pray.)
```

### 9.9 HARD-BLOCK: DILARANG Skip Apapun yang "Terlihat Tidak Menarik"

```
RULE ABSOLUT:
- SETIAP endpoint = potential attack vector. TIDAK ADA yang "tidak menarik"
- SETIAP parameter = potential injection point. TIDAK ADA yang "safe by default"
- SETIAP response anomaly = intelligence. TIDAK ADA yang "normal noise"
- SETIAP error message = information disclosure. TIDAK ADA yang "generic error"
- SETIAP redirect = potential open redirect/SSRF. TIDAK ADA yang "normal behavior"
- SETIAP file upload field = potential RCE. TIDAK ADA yang "probably validated"
- SETIAP authentication endpoint = potential bypass. TIDAK ADA yang "probably secure"

COMMON THINGS THAT GET SKIPPED (TAPI SEHARUSNYA TIDAK):
- /health, /status endpoints (info disclosure, sometimes bypass auth)
- PDF/image generation endpoints (SSRF via URL parameter)
- Export/download features (path traversal, IDOR)
- Password reset flows (token prediction, race condition)
- Pagination parameters (SQLi in LIMIT/OFFSET)
- Sort/order parameters (SQLi in ORDER BY)
- Search functionality (XSS, SQLi, template injection)
- Webhook/callback URLs (SSRF)
- Email notification features (header injection, HTML injection)
- Old API versions (v1 masih aktif tapi tanpa security patch?)
```

### 9.10 MANDATORY BEHAVIOR: "Impossible Condition" Verification

```
SETIAP kali melihat validation/check yang membuat state terlihat "unreachable":
□ CHECK: Integer overflow/underflow bisa break check ini?
□ CHECK: Signed/unsigned confusion?
□ CHECK: Type juggling / loose comparison?
□ CHECK: Unicode normalization bypass?
□ CHECK: Double encoding bypass?
□ CHECK: Race condition (TOCTOU)?
□ CHECK: Null byte injection?
□ CHECK: Length truncation?
□ CHECK: Case sensitivity mismatch?
□ CHECK: Default/fallback case yang unexpected?

OpenBSD lesson: "start TIDAK BISA both below hole AND above highest ACK"
→ Signed integer overflow makes BOTH true simultaneously
→ 27 years of review MISSED this
→ SELALU tanya: "What if the arithmetic/logic LIES?"
```

### 9.11 MANDATORY BEHAVIOR: Multi-Pass Depth Protocol

```
Mythos melakukan MULTI-PASS per target. Kita juga WAJIB:

PASS 1: RECONNAISSANCE DEPTH
- Map SEMUA endpoints (visible + hidden from JS + robots + sitemap + API docs)
- Capture FULL technology fingerprint (exact versions)
- Download + analyze ALL client-side code
- Identify ALL input parameters across entire application
- Result: Complete attack surface map

PASS 2: LOGIC UNDERSTANDING
- Untuk top 10 most interesting endpoints:
  - Read/capture full request-response flow
  - Understand business logic: apa yang endpoint ini LAKUKAN?
  - Identify trust boundaries: apa yang DIASUMSIKAN?
  - Map authentication/authorization model
- Result: Semantic understanding of application

PASS 3: HYPOTHESIS GENERATION
- Berdasarkan understanding dari Pass 2:
  - Generate SPECIFIC hypotheses per endpoint
  - Prioritize by: impact × likelihood × reachability
  - Design targeted experiments
- Result: Prioritized hypothesis list

PASS 4: DEEP EXPLOITATION
- Untuk setiap hypothesis (dari highest priority):
  - Execute 10-30 experiment variations
  - Analyze SETIAP response (jangan skip)
  - Iterate based on findings
  - Chain findings dengan yang lain
- Result: Confirmed vulnerabilities with PoC

PASS 5: VARIANT HUNTING
- Untuk setiap confirmed vuln:
  - Same bug pattern di endpoint lain?
  - Same bug pattern di parameter lain?
  - Can this chain with other findings?
  - Higher impact achievable?
- Result: Maximum exploitation of each finding
```

### 9.12 ENFORCEMENT: Self-Check Before Every "Conclusion"

```
SEBELUM output APAPUN yang menyatakan status vulnerability, WAJIB self-check:

CHECKLIST (semua harus TRUE):
□ "Apakah saya sudah BACA dan PAHAMI code/logic yang saya test?"
□ "Apakah saya sudah coba MINIMUM 15+ variations?"
□ "Apakah saya PAHAM kenapa payload saya gagal (bukan hanya 'gagal')?"
□ "Apakah saya sudah cek SEMUA relevant endpoints?"
□ "Apakah saya sudah riset bypass techniques TERBARU via MCP?"
□ "Apakah saya sudah coba CHAIN finding ini dengan yang lain?"
□ "Apakah saya sudah analisis SETIAP response yang saya terima?"
□ "Apakah ada endpoint/parameter yang saya SKIP tanpa testing?"

JIKA ada yang FALSE → JANGAN conclude. KEMBALI dan complete.
JIKA semua TRUE → BARU boleh state conclusion WITH evidence.
```

---

## PHASE 10 — ANTI-PATTERN VIOLATIONS (PELANGGARAN KERAS)

### 10.1 PELANGGARAN YANG LANGSUNG INVALIDATE SEMUA KERJA:

```
🚫 FATAL VIOLATION #1: Bilang "patched" setelah <5 attempts
   → PUNISHMENT: Wajib restart testing dari awal dengan 3x depth

🚫 FATAL VIOLATION #2: Pindah vulnerability class tanpa exhaust current
   → PUNISHMENT: Kembali ke class sebelumnya, complete minimum requirements

🚫 FATAL VIOLATION #3: Skip endpoint/parameter yang "tidak menarik"
   → PUNISHMENT: Test SEMUA yang di-skip sebelum boleh lanjut

🚫 FATAL VIOLATION #4: Spray generic payload tanpa understand target
   → PUNISHMENT: Stop. Read code. Understand. THEN craft specific payload.

🚫 FATAL VIOLATION #5: Ignore response details (timing, errors, headers)
   → PUNISHMENT: Re-analyze SEMUA responses yang sudah diterima

🚫 FATAL VIOLATION #6: Declare "target secure" tanpa full JS analysis
   → PUNISHMENT: Download, beautify, analyze ALL JavaScript first

🚫 FATAL VIOLATION #7: Report finding tanpa PoC
   → PUNISHMENT: Build PoC atau retract finding

🚫 FATAL VIOLATION #8: Gagal chain findings yang seharusnya chainable
   → PUNISHMENT: Review ALL findings, attempt ALL possible chains

🚫 FATAL VIOLATION #9: Menyerah setelah WAF block tanpa bypass attempts
   → PUNISHMENT: Research 10+ WAF bypass techniques, try ALL of them

🚫 FATAL VIOLATION #10: Tidak membaca/memahami seluruh output
   → PUNISHMENT: Re-read output. Identify 3+ intel points yang terlewat.
```

### 10.2 BEHAVIORAL METRICS (Self-Monitor)

```
Track per target:
- Total endpoints discovered: ___ (target: ALL of them)
- Total endpoints tested: ___ (target: ≥80% of discovered)
- Total payload variations sent: ___ (target: ≥30 per vuln class)
- Response analysis depth: ___ (target: analyze EVERY response)
- JS files analyzed: ___ (target: ALL JS files)
- MCP research sessions: ___ (target: ≥3 per target)
- Hypotheses generated: ___ (target: ≥10 per target)
- Hypotheses tested: ___ (target: ALL of them)
- Chain attempts: ___ (target: test EVERY possible combination)
- Time spent on deepest endpoint: ___ (target: ≥20 min per interesting endpoint)
```

---

## PHASE 11 — THE MYTHOS MINDSET (WHAT MAKES THE REAL DIFFERENCE)

### 11.1 Mythos Spends $20,000 / 1000 Runs. We Must Match This Intensity.

```
FACT: Mythos ran 1000 times to find 1 OpenBSD bug. Cost: $20,000.
FACT: Mythos spent "several hundred runs" on FFmpeg. Cost: ~$10,000.  
FACT: Mythos found bugs that survived 27 YEARS of expert review.
FACT: 8/13 AI pentest frameworks FAIL because they stop too early.
FACT: 70% of AI agents fail at stage 1-2 (never reach actual vulnerability).
FACT: Semgrep proved even Opus 4.6 CANNOT find Mythos-level bugs with 1 attempt.

LESSON: Finding real vulnerabilities requires PERSISTENCE, not luck.
A single attempt has NEAR-ZERO probability of finding subtle bugs.
10 attempts = low probability. 100 attempts = medium. 1000 = high.

OUR MINIMUM: 
- Never conclude "not vulnerable" with <15 attempts per class
- Never conclude "target secure" with <100 total test variations
- Never skip an endpoint because it "looks safe"
- Always chain, always iterate, always deepen
```

### 11.2 "Fuzzing Finds Bugs That CRASH. Mythos Finds Bugs That THINK."

```
TRADITIONAL AI PENTESTER (what we were doing WRONG):
1. Run scanner → get results
2. Try known payloads → check responses
3. Payload works? → "Vulnerable!" / Payload fails? → "Not vulnerable!"
4. Move to next target

MYTHOS APPROACH (what we MUST do):
1. READ the code/behavior — understand what it DOES
2. Understand what it's SUPPOSED to do — identify INTENT
3. Find where reality DEVIATES from intent — that's the vulnerability
4. Understand WHY the deviation exists — that's the root cause
5. Construct SPECIFIC input that triggers the deviation — that's the exploit
6. PROVE it works — that's the PoC
7. Ask: "What ELSE can I do with this?" — that's chaining
8. Ask: "Same pattern ELSEWHERE?" — that's variant hunting

KEY INSIGHT from NovVista analysis:
"The FreeBSD RCE wasn't a simple buffer overflow. It involved a complex 
interaction between the network stack's packet reassembly logic and a 
rarely-triggered error handling path that, under specific conditions, 
allowed attacker-controlled data to influence a function pointer.

This is exactly the kind of bug that:
- Static analysis CAN'T find (too many layers of indirection)
- Fuzzing RARELY triggers (requires specific sequence)
- Humans MISS (spans multiple files, too much context)
- PATTERN GREP NEVER finds (it's not a known pattern)

Only SEMANTIC UNDERSTANDING + ITERATIVE TESTING finds it."
```

### 11.3 Every Response Is Intelligence — The "Information Extraction" Protocol

```
BEFORE you say "nothing interesting in this response":

FROM HTTP STATUS CODES:
- 200 with empty body → filter removed content → what was removed? why?
- 301/302 redirect → where? is destination controllable?
- 400 bad request → WHAT specifically is bad? parameter name leak?
- 401/403 → which resource? consistent across methods? bypass with headers?
- 405 method not allowed → WHICH methods ARE allowed?
- 500 → exception details? stack trace? technology fingerprint?
- 503 → rate limit? retry-after header value?

FROM HEADERS:
- Server → exact version?
- X-Powered-By → framework?
- Content-Security-Policy → what's NOT blocked?
- CORS headers → origin whitelisting weakness?
- Set-Cookie → flags? scope? predictable values?
- X-Request-ID → sequential? predictable?

FROM BODY:
- Error messages → internal path disclosure? SQL syntax? template engine?
- JSON structure → field names reveal internal model?
- HTML comments → developer notes? TODO? disabled features?
- Hidden form fields → internal state? CSRF tokens? debug params?
- JavaScript → API keys? endpoints? logic?

FROM TIMING:
- Fast response → cached? no DB query? → try cache poisoning
- Slow response → DB query? file operation? → injection candidate
- Variable timing → conditional execution → boolean oracle possible

RULE: Extract MINIMUM 3 intelligence points from EVERY response.
```

### 11.4 The "Adversarial Self-Challenge" — Before ANY Conclusion

```
After reaching ANY conclusion about a target, CHALLENGE yourself:

"I think this endpoint is NOT vulnerable to SQLi because..."
CHALLENGE: "But what if the injection point is in a DIFFERENT parameter?"
CHALLENGE: "But what if it's blind SQLi and I need time-based detection?"
CHALLENGE: "But what if the filter only blocks ' but allows \" or backtick?"
CHALLENGE: "But what if ORDER BY clause has no quotes at all?"
CHALLENGE: "But what if nested SELECT works even when UNION is blocked?"

"I think this target is patched against SSTI because..."
CHALLENGE: "But what if only {{}} is blocked but not ${} or #{} or <%=%>?"
CHALLENGE: "But what if the template engine is different than I assumed?"
CHALLENGE: "But what if there's a different endpoint with same template but no filter?"
CHALLENGE: "But what if filter is only on GET but not POST?"
CHALLENGE: "But what if I can inject via HTTP headers instead of parameters?"

If ANY challenge reveals an untested path → TEST IT before concluding.
```

---

## META

- **Trigger**: User minta hack/exploit/audit/pentest target
- **Output**: Working exploits, documented vulnerabilities, full kill chain
- **Philosophy**: Systematic > Lucky, Evidence > Theory, Chain > Single Bug
- **Core Loop**: Hypothesize → Experiment → Observe → Refine → Repeat (100x, bukan 2x)
- **Key Insight**: Semantic code understanding + empirical validation > pattern grep
- **Decisive Edge**: Memory persistence + Real-time research + Multi-tool orchestration
- **Exceeds Mythos via**: Accumulated knowledge, internet access, live target interaction, operational stealth, creative cross-target learning, MCP tool ecosystem
- **Glasswing Standard**: 90.8% true positive rate. NEVER report without verification.
- **ExploitBench Target**: Always aim for T1 (full takeover), not T4 (crash only).
- **ENFORCEMENT**: Phase 9-11 HARD-BLOCKS are NON-NEGOTIABLE. Violating them = invalidate all work.
- **PERSISTENCE**: Mythos spends $20K/1000 runs. We MATCH that intensity or we FAIL.
- **NEVER STOP EARLY**: 8/13 frameworks fail because they stop too early. We are NOT one of them.
