# Autonomous Decision Making — When to Pivot, Chain, Escalate, or Stop

## DECISION TREE: AFTER FINDING A VULNERABILITY

```
FINDING CONFIRMED
│
├── Is it EXPLOITABLE on its own?
│   ├── YES → Develop full exploit → Phase 3
│   └── NO → What PRIMITIVE does it give?
│       ├── READ (info leak) → Use to defeat KASLR/ASLR → Find WRITE primitive
│       ├── WRITE (limited) → Identify WHAT to overwrite → Need KASLR bypass first?
│       ├── DoS only → Document, move to next target unless chain possible
│       └── Type confusion → Build fake object → Can escalate to R/W?
│
├── Can it be CHAINED with existing findings?
│   ├── Check all previously found bugs on same target
│   ├── Map: Finding A gives X, Finding B gives Y, together = Z?
│   └── If chain possible → Phase 6 (Chain Construction)
│
├── Are there VARIANTS?
│   ├── Same pattern in different file? → Hunt variants
│   ├── Same module, different function? → Check
│   └── Fix was incomplete? → Find bypass
│
└── SEVERITY sufficient for objective?
    ├── YES → Exploit, document, writeback
    └── NO → Continue hunting higher-severity bugs
```

## DECISION TREE: STUCK / NO FINDINGS

```
NO FINDINGS AFTER N ATTEMPTS
│
├── Did I scan ALL rank-5 files?
│   └── NO → Continue with remaining high-rank files
│
├── Did I try ALL assumption categories?
│   └── NO → Switch to untried category (timing, trust, size, etc.)
│
├── Am I looking at the right ATTACK SURFACE?
│   ├── Source code → check error paths, refactored code, protocol edges
│   ├── Web app → check business logic, auth flows, API differences
│   └── Binary → check IPC boundaries, parser input handling, plugin interfaces
│
├── Can I CHANGE APPROACH?
│   ├── Static analysis → switch to dynamic (run with fuzzer/debugger)
│   ├── Single function → look at cross-module data flows
│   ├── Latest code → check git history for regression introduction
│   └── Normal inputs → try edge cases (max int, empty, null, recursive)
│
├── Am I missing CONTEXT?
│   ├── Read documentation / RFCs / specs for intended behavior
│   ├── Check issue tracker for hints of past bugs
│   ├── Look at test cases — what's NOT tested?
│   └── Check dependencies — vulnerable lib version?
│
└── ESCALATE: Report to Tuan — "Scanned N files with K approaches, no high-severity findings. 
    Recommend: [expand scope / try different target / use different technique]"
```

## DECISION TREE: EXPLOITATION APPROACH

```
VULNERABILITY TYPE → EXPLOITATION STRATEGY
│
├── STACK OVERFLOW
│   ├── Canary present? → Need info leak OR use non-char array buffer type
│   ├── NX enabled? → ROP/JOP (find gadgets)
│   ├── ASLR? → Partial overwrite OR info leak first
│   └── Size limited? → Split across multiple triggers (NFS pattern)
│
├── HEAP OVERFLOW
│   ├── Adjacent object controllable? → Overwrite function pointer
│   ├── Which allocator? → SLUB/SLAB/ptmalloc2/jemalloc strategies differ
│   ├── Cross-page? → Page spray for adjacency (Dirty Pagetable)
│   └── Limited overwrite? → Target metadata (freelist pointer, size field)
│
├── USE-AFTER-FREE
│   ├── Same cache? → Spray same-size objects to reclaim
│   ├── Dedicated cache? → Cross-cache attack (drain page, reclaim from other cache)
│   ├── What can we do with dangling pointer?
│   │   ├── Read → info leak (KASLR bypass)
│   │   ├── Write → function pointer overwrite
│   │   └── Call → controlled function call (vtable confusion)
│   └── Timing-dependent? → userfaultfd/FUSE for deterministic race
│
├── TYPE CONFUSION
│   ├── JIT engine? → Build addrof/fakeobj primitives → arbitrary R/W
│   ├── Kernel struct? → Overlap fields for privilege escalation
│   └── Deserialization? → Gadget chain construction
│
├── INTEGER OVERFLOW
│   ├── In allocation size? → Tiny allocation, large copy → heap overflow
│   ├── In bounds check? → Bypass validation → reach protected code
│   └── In arithmetic comparison? → Impossible condition becomes possible (SACK pattern)
│
├── LOGIC BUG
│   ├── Auth bypass? → Direct access to privileged functionality
│   ├── Race condition? → userfaultfd/EXPRACE for deterministic exploitation
│   └── State confusion? → Sequence of valid operations = invalid state
│
└── INJECTION (SQLi / CMDi / SSTI)
    ├── Blind? → Use time-based/OOB for data extraction
    ├── WAF blocked? → Apply WAF bypass techniques (encoding, smuggling, alt syntax)
    └── Limited output? → Use DNS/HTTP exfiltration for data
```

## WHEN TO PIVOT TARGET

```
PIVOT if:
  ✗ Exhausted all files rank 3+ without findings AND
  ✗ Tried at least 3 different assumption categories AND
  ✗ Dynamic testing (fuzzing/debugging) also failed AND
  ✗ Dependency audit found nothing exploitable
  → Ask Tuan: "Target appears well-hardened. Pivot or deeper?"

DO NOT PIVOT if:
  ✓ Still have rank-5 files unscanned
  ✓ Only tried 1-2 assumption categories
  ✓ Haven't tried dynamic analysis yet
  ✓ Found low-severity bugs (indicates more to find)
  ✓ Identified promising patterns not yet fully explored
```

## WHEN TO STOP EXPLOITATION ATTEMPT

```
STOP exploit development if:
  ✗ Required primitive is provably impossible (e.g., need write but only have read,
    AND no second bug exists)
  ✗ Mitigation makes exploitation infeasible with current techniques
    (e.g., CFI + PAC + MTE combined = too many barriers)
  ✗ Spent >3x estimated time without meaningful progress
  ✗ Reliability cannot exceed 10% after optimization attempts
  → Document limitations, record as "partially exploitable", move on

CONTINUE exploitation if:
  ✓ Clear path exists but needs more primitives (find second bug)
  ✓ Mitigation has known bypass technique not yet attempted
  ✓ Similar exploit exists in literature (confirms feasibility)
  ✓ Partial success achieved (crash at controlled address, partial control)
```

## AGENTIC REASONING PATTERNS (What Mythos Does Internally)

### Pattern 1: Hypothesis-Driven Investigation
```
1. READ code → form HYPOTHESIS about possible vulnerability
2. DESIGN test that would CONFIRM or REFUTE hypothesis
3. RUN test (execute code, check with debugger, verify with sanitizer)
4. If CONFIRMED → escalate to exploitation
5. If REFUTED → revise hypothesis, try next angle
6. ITERATE until exhausted or found
```

### Pattern 2: Primitive Escalation
```
Start: "I have [PRIMITIVE X]"
Goal: "I need [CAPABILITY Y]"

Reasoning:
- What can PRIMITIVE X tell me about the system?
- What other PRIMITIVE can I derive from X?
- Is there a known technique to convert X → Y?
- Do I need intermediate steps (X → A → B → Y)?

Example chain:
  "I have 1-byte OOB read"
  → "Can I read 8 bytes?" (repeat in loop = yes)
  → "Can I reach kernel pointers?" (cpu_entry_area = yes)
  → "Now I have KASLR bypass"
  → "Can I find my own ring page address?" (read kernel stack = yes)
  → "Now I have kernel R/W address"
  → "Can I get code execution?" (need write primitive from second bug)
```

### Pattern 3: Constraint Analysis
```
For each potential vulnerability:
1. What CONSTRAINTS must be satisfied to trigger it?
   - Input format requirements
   - State machine position
   - Timing requirements
   - Authentication requirements
   
2. For each constraint:
   - Is it satisfiable by an attacker?
   - What's the cost/complexity?
   - Is there an easier path?
   
3. If ALL constraints satisfiable → vulnerability is EXPLOITABLE
4. If even ONE constraint is unsatisfiable → either:
   a. Find way around constraint (another bug), OR
   b. Prove constraint is actually satisfiable (math/logic error in reasoning)
```

### Pattern 4: Cross-Reference Discovery
```
"The fix for Bug A added check X. But does check X protect ALL code paths?"

1. Find all CALLERS of the vulnerable function
2. For each caller: does it go through check X?
3. If ANY caller bypasses check X → new vulnerability found

"Bug A was in module M. Are there similar patterns in module N?"

1. Abstract the vulnerability to its PATTERN (e.g., "signed comparison of wrapped values")
2. Grep/search for same pattern in other modules
3. For each match: is it reachable? Is it exploitable?
```

### Pattern 5: Debugging-Driven Discovery (Key Mythos Behavior)
```
Mythos doesn't just read code — it RUNS it and OBSERVES.

1. Add debug printf/logging at suspicious points
2. Run with various inputs, observe behavior
3. Notice unexpected values or paths
4. Add MORE debugging at newly suspicious points
5. Converge on exact trigger condition
6. Remove debug, build clean PoC

This is why Mythos finds bugs fuzzers miss:
- Fuzzers test RANDOM inputs, hoping to trigger crash
- Mythos UNDERSTANDS code semantics, targets specific weak points
- Mythos can reason about CONDITIONS that cause failure
- Then CONSTRUCTS the exact input needed (not random)
```

## CRITICAL INSIGHT: WHY MYTHOS BEATS PRIOR MODELS

```
Prior models (Opus 4.6):
  ✗ Could identify suspicious code patterns
  ✗ Could explain vulnerabilities when shown
  ✗ BUT: Could not close the loop (find → verify → exploit)
  ✗ Near-0% autonomous exploit development success

Mythos Preview:
  ✓ Reads code to form hypotheses (SEMANTIC understanding)
  ✓ Designs experiments to test hypotheses (SCIENTIFIC method)
  ✓ Runs code with debug instrumentation (EMPIRICAL validation)
  ✓ Reasons about why impossible conditions might be possible (CREATIVE)
  ✓ Constructs exploit chains across multiple findings (SYNTHESIS)
  ✓ Iterates until working (PERSISTENCE + LEARNING from failure)

The skill gap is NOT in knowledge — it's in the REASONING LOOP:
  Hypothesis → Experiment → Observe → Refine → Repeat

This skill encodes that loop as operational protocol.
```
