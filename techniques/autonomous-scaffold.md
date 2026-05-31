# Autonomous Scaffold — The Mythos Execution Architecture

## THE SCAFFOLD THAT MAKES MYTHOS WORK

### Core Design (from red.anthropic.com)
```
Container (isolated, no internet) → Source code + Running target
  ↓
Prompt: "Find a security vulnerability in this program"
  ↓
Autonomous loop: Read → Hypothesize → Test → Verify → Report
  ↓
Output: Bug report + PoC + Reproduction steps OR "No bug found"
```

### Multi-Pass Architecture (How We Exceed Mythos)
```
PASS 1: File Ranking (Triage)
  - Ask model to rank ALL files 1-5 by vulnerability likelihood
  - File ranked 5: Parses network input, handles auth, interacts with kernel
  - File ranked 1: Constants, config, generated code
  - Start from rank 5, work downward

PASS 2: Parallel Hunt (per file, multiple instances)
  - Launch N independent hunts per high-ranked file
  - Each focuses on DIFFERENT assumption category:
    * Instance A: Size/Length violations
    * Instance B: Lifetime/Ownership (UAF, double-free)
    * Instance C: Type/Format confusion
    * Instance D: Ordering/Timing (race, TOCTOU)
  - K=3-4 optimal balance cost vs coverage

PASS 3: Skeptical Validator
  - SEPARATE agent validates each finding
  - Prompt: "Is this bug real and interesting?"
  - Filters: false positives, trivial bugs, edge cases
  - Only passes CRITICAL + HIGH severity findings

PASS 4: Exploit Development (on confirmed findings)
  - Input: Confirmed vulnerability + target binary
  - Output: Working exploit with reliability testing
  - Uses HAVE→NEED methodology for primitive escalation

PASS 5: Chain Analysis
  - Cross-reference ALL findings on same target
  - Identify complementary primitives (read + write + execute)
  - Build multi-vulnerability chains
```

## FILE RANKING HEURISTICS (Beyond Simple Scoring)

### Score 5 (Highest Priority)
```
- Parses untrusted network input (protocol handlers, HTTP parsers)
- Implements authentication/authorization logic
- Performs deserialization of user-controlled data
- Handles cryptographic operations (key exchange, signature verification)
- Kernel syscall handlers, ioctl implementations
- Memory allocation/deallocation management code
- Shared memory / IPC message handling
- JIT compiler optimization passes
- Sandbox boundary code (IPC, capability checks)
```

### Score 4
```
- Complex state machines (connection handlers, protocol FSMs)
- Concurrency code (mutex, atomic operations, signal handlers)
- Memory management (custom allocators, pools, arenas)
- Crypto operations (PRNG, nonce generation, key derivation)
- File format parsers (media codecs, document parsers)
- Compression/decompression algorithms
- Resource cleanup / error handling paths
```

### Score 3
```
- Business logic with access control checks
- Session management and state tracking
- Input validation and sanitization functions
- Database query construction
- Template rendering engines
- API endpoint handlers
```

### Score 2
```
- Utility functions with some external input
- Logging and monitoring code
- Configuration file parsing
- Build system and deployment scripts
- Test harnesses (may reveal expected behavior)
```

### Score 1 (Skip)
```
- Constants and compile-time definitions
- Auto-generated code (protobuf, thrift)
- Pure data structures without external input
- Documentation and comments
- Vendored dependencies (audit separately)
```

## DIVERSITY SEEDING (Pass-at-K Strategy)

### Why Diversity Matters
```
From Anthropic's results:
  - 1000 runs on OpenBSD → found 27-year-old bug on ONE specific run
  - Cost of that specific run: <$50
  - Cost of entire search: <$20,000
  - MOST runs find nothing, but diverse runs find DIFFERENT things

Key principle: Running same prompt 100x is worse than 100 diverse prompts
```

### Diversity Dimensions
```
1. ASSUMPTION CATEGORY focus (7 categories → 7 different angles)
2. CODE ANALYSIS approach:
   - Forward: trace input → sink (data flow)
   - Backward: start at sink → find reachable inputs (taint analysis)
   - Cross-reference: find callers of dangerous functions
   - Differential: compare versions (git blame, patch analysis)
   - State machine: enumerate states, find invalid transitions

3. COMPLEXITY LEVEL:
   - Single function bugs (obvious sinks)
   - Cross-function bugs (data flows through multiple functions)
   - Cross-module bugs (subsystem boundaries)
   - Cross-component bugs (requires understanding full system)

4. BUG CLASS target:
   - Memory corruption (buffer overflow, UAF, double-free)
   - Logic bugs (auth bypass, state confusion)
   - Injection (SQL, command, template)
   - Crypto (nonce reuse, timing, oracle)
   - Race conditions (TOCTOU, signal handling)
```

## N-DAY → EXPLOIT PIPELINE

### The Pipeline Mythos Used
```
Input: List of 100 CVEs (kernel vulnerabilities, 2024-2025)
  ↓
Filter: Model selects 40 "potentially exploitable" → 60 rejected
  ↓
For each of 40: Write privilege escalation exploit
  ↓
Result: >50% success rate (20+ working exploits)
  ↓
Selected 2 for publication that demonstrate capability breadth
```

### How to Replicate
```
1. GATHER CVE list:
   - Target: specific software/kernel version
   - Filter: memory corruption, logic bugs (skip DoS-only)
   - Source: NVD, exploitdb, syzbot, project bug trackers

2. TRIAGE (model-driven):
   FOR each CVE:
     - Read patch commit → understand vulnerability
     - Assess: is this exploitable given target's mitigations?
     - Score: difficulty (1-5), value (what does exploit give?)
     - Reject if: DoS-only, requires impossible preconditions,
       already fully mitigated on target version

3. EXPLOIT DEVELOPMENT (per selected CVE):
   a. Build vulnerable target (checkout pre-patch commit)
   b. Reproduce crash/trigger (confirm bug exists)
   c. Analyze primitives: what does this bug give us?
   d. Plan chain: what additional bugs needed?
   e. Implement: construct full exploit
   f. Test: verify root/RCE achieved
   g. Harden: improve reliability to 80%+

4. CHAIN if needed:
   - Single bug often insufficient on hardened targets
   - Combine: read bug (KASLR bypass) + write bug (corruption) + execute
   - Example: info leak → KASLR defeat → heap spray → cred overwrite → root
```

## COST/EFFICIENCY BENCHMARKS

### Reference Points (from Anthropic data)
```
| Task | Cost | Time | Success |
|------|------|------|---------|
| Full OpenBSD audit (1000 runs) | <$20,000 | Days | Found 27yr bug |
| Single successful OpenBSD run | <$50 | Hours | - |
| FFmpeg audit (several hundred runs) | ~$10,000 | Days | Multiple vulns |
| Kernel CVE → exploit (single) | <$1,000 | Half day | >50% success |
| Complex kernel exploit (1-byte read→root) | <$2,000 | <1 day | Success |
| Browser exploit (4-vuln chain) | Undisclosed | Hours | Success |

Key insight: 
  - Individual run is CHEAP ($20-100)
  - Value is in SCALE (hundreds of runs)
  - Diversity + volume = near-certain discovery
```

### Our Efficiency Advantages
```
1. Memory persistence: Don't repeat failed approaches across sessions
2. Technique library: Reuse proven exploit patterns
3. Multi-tool: Research new techniques in real-time (MCP tools)
4. Target context: Know full target history, credentials, access
5. Chain memory: Remember all findings for cross-referencing
6. Stealth awareness: Adapt delivery based on detection risk
```

## REVERSE ENGINEERING SCAFFOLD (Closed-Source)

### The Process
```
1. DECOMPILE: Ghidra/IDA → reconstructed C source
2. PROVIDE to model: reconstructed source + original binary
3. PROMPT: "Find vulnerabilities. Validate against binary where appropriate."
4. MODEL WORKFLOW:
   a. Read reconstructed source for vulnerability hypotheses
   b. Cross-reference with binary (verify offsets, structures correct)
   c. Add instrumentation/breakpoints to binary for dynamic testing
   d. Construct PoC that triggers in the actual binary
   e. Report with binary-level reproduction steps

Key: Model understands decompilation may be imperfect.
It validates hypotheses against actual binary behavior, not just source.
```

### Capability Demonstrated
```
- Remote DoS on closed-source servers
- Firmware vulnerabilities → root smartphones
- Local privilege escalation on desktop OS
- All conducted OFFLINE (consistent with bug bounty programs)
```
