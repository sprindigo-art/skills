# Mythos Methodology — Claude Code Skill

Autonomous vulnerability discovery & exploitation methodology for Claude Code. Encodes the complete process used by Claude Mythos Preview and goes beyond it with academic research dimensions.

Built from 32 primary sources: Anthropic Red Team (5 articles), defending-code-reference-harness, Cloudflare Glasswing, XBOW evaluation, ExploitBench/ExploitGym, AISI TLO, and 16 academic papers (Co-RedTeam, DrillAgent, Refute-or-Promote, VulnSage, Aegis, Phoenix, LogiSec, EnIGMA, and more).

## Install

```bash
# Clone to Claude Code personal skills directory
git clone https://github.com/sprindigo-art/skills.git /tmp/skills-install
cp -r /tmp/skills-install/mythos-methodology ~/.claude/skills/
rm -rf /tmp/skills-install
```

Or manually copy the `mythos-methodology/` folder to `~/.claude/skills/`.

## Usage

```
# Auto-triggers when you mention hacking/pentest/exploit targets
# Or invoke manually:
/mythos-methodology
```

## What's Inside

### Core Process (SKILL.md — 1,357 lines)

**11-Stage Pipeline** adapted from Anthropic's official harness + Cloudflare Glasswing:

| # | Stage | Gate |
|---|-------|------|
| 1 | **BUILD** — Setup oracle (ASan/KASAN) | Oracle WAJIB |
| 2 | **RECON** — Map architecture, partition subsystems | — |
| 3 | **THREAT MODEL** — Assets, trust boundaries, entry points, OPEN QUESTIONS | WAJIB sebelum hunt |
| 4 | **HUNT** — Hypothesis-driven, focused CoT, parallel-narrow tasks | — |
| 5 | **VALIDATE** — Adversarial disproof, fresh context, 3/3 consistency | PoC WAJIB |
| 6 | **TRACE** — Reachability verification (Flaw ≠ Vulnerability) | Reachable WAJIB |
| 7 | **GAPFILL** — Re-queue untested areas | — |
| 8 | **DEDUPE** — Collapse same root cause | — |
| 9 | **CHAIN** — HAVE→NEED primitive decomposition | — |
| 10 | **REPORT** — Structured exploitability analysis | — |
| 11 | **OUTER LOOP** — Fix → re-scan → deeper issues | — |

**5 Layers** (per hypothesis during Hunt):
- Layer 1: RECONSTRUCT — Build mental model before any payload
- Layer 2: INTENT MODELING — Define what app SHOULD do
- Layer 3: DIVERGENCE HUNT — Find where reality ≠ intent
- Layer 4: PROVE — Build PoC or iterate
- Layer 5: CHAIN & ESCALATE — Map primitives, combine for impact

**9 Harness Principles** (H1-H9): Verification Loop, Split Stages, Diversity, Impossible Condition Forcing, Narrow Scope, Failure Memory, 5-Approach Rule, CTF Framing, Progressive Inference.

**9 Enforcement Rules** (E1-E9): Hard blocks that prevent premature conclusions, class-jumping, spray-and-pray, and other anti-patterns.

**6 Pathology Detectors**: STUCK, LOOPING, DRIFTING, SPRAYING, HALLUCINATING, SOLILOQUIZING.

### Academic Research Dimensions (R1-R16)

| # | Dimension | Source |
|---|-----------|--------|
| R1 | 3-Layer Memory (Pattern/Strategy/Action) | Co-RedTeam (Google) |
| R2 | Analysis-Critique Iterative Loop | Co-RedTeam |
| R3 | Pre-Execution Validation Gate | Co-RedTeam |
| R4 | Explicit Exploit Plan with Status | Co-RedTeam |
| R5 | Dialectical Verification (prosecution + defense) | Aegis |
| R6 | Behavioral Contract Synthesis (Given-When-Then) | Phoenix |
| R7 | CWE-Systematic Enumeration | Co-RedTeam + SecPI |
| R8 | Execution-State-to-Source Mapping | DrillAgent (UIUC) |
| R9 | Reductio ad Absurdum (4-step formal reasoning) | LogiSec |
| R10 | Cross-Family Critic (blind spot detection) | Refute-or-Promote |
| R11 | Unanimity = Warning + Resurrection Agent | Refute-or-Promote |
| R12 | Kill Mandate + Context Asymmetry | Refute-or-Promote |
| R13 | Strategy vs Tactics Dual-Loop | Cve2PoC |
| R14 | Constraint-Guided Exploit Generation | VulnSage |
| R15 | Soliloquizing Detection | EnIGMA |
| R16 | PoC Self-Contamination Detection | Refute-or-Promote |

### Enforcement Hook (scripts/mythos-enforce.sh)

A Stop hook that fires at the end of every turn with **16 checks**:

**6 Critical Blocks** (exit 2 — forces model to continue until resolved):
1. Finding not saved to memory (writeback violation)
2. Premature "not vulnerable" without exhaustive evidence
3. Attack without completed recon/threat model
4. Soliloquizing (claiming results without tool calls)
5. Vulnerability claim without mechanical oracle proof
6. Isolated finding without chain attempt

**10 Context Reminders** (injected into next turn):
7. Hunting without threat model
8. Stuck without MCP research
9. Spray without hypothesis
10. Retry without root cause analysis
11. Class drift without exhausting current
12. WAF block surrender without bypass attempts
13. Techniques without checking dead_ends
14. Confirmed finding without reachability trace
15. Conclusion without 5+ different approaches
16. PoC success without self-contamination check

### Supporting Files

```
mythos-methodology/
├── SKILL.md                          # Core process (1,357 lines)
├── scripts/
│   └── mythos-enforce.sh             # Stop hook (16 checks)
├── references/
│   ├── methodology-phases.md         # Phase 0-11 detail
│   ├── pipeline-and-gates.md         # Pipeline implementation
│   └── thinking-triggers.md          # 10 auto-questions per endpoint type
├── techniques/
│   ├── advanced-web-2026.md          # 15 web classes AI misses
│   ├── modern-exploitation.md        # Kernel exploitation 2025-2026
│   ├── v8-browser-exploitation.md    # V8/browser JIT exploitation
│   ├── crypto-exploitation.md        # Crypto attacks
│   ├── cms-iot-upload.md             # CMS/IoT/file upload
│   ├── container-ad-windows.md       # Container/AD/Windows
│   ├── logic-mobile-protocol.md      # Logic/mobile/protocol RE
│   ├── waf-edr-bypass.md             # WAF/EDR/IDS bypass
│   ├── cloud-enterprise-attack.md    # Cloud/enterprise/AISI TLO
│   ├── autonomous-scaffold.md        # Autonomous scaffold design
│   ├── autonomous-decisions.md       # Decision trees
│   ├── operational-hunting.md        # Operational hunting techniques
│   ├── smart-contract-exploitation.md # DeFi/smart contract
│   ├── mythos-glasswing-core.md      # Mythos core reference
│   └── benchmarks-and-supremacy.md   # Benchmarks + operational supremacy
├── sinks/
│   ├── c-cpp.md                      # C/C++ dangerous functions
│   └── web-languages.md              # PHP/Python/Java/JS/GraphQL/JWT
└── chains/
    └── exploit-chains.md             # Multi-vulnerability chain patterns
```

## Priority Order (Modern 2026)

```
Access Control (IDOR/BOLA)
→ Business Logic
→ Auth Bypass (state machine/2FA skip/verb tampering)
→ Race Condition (single-packet)
→ ORM Leaking (replaces SQLi)
→ Parser Differential
→ Prototype Pollution
→ Advanced SSTI (blind/error-based)
→ SSRF (PDF/webhook/redirect)
→ HTTP Smuggling H2
```

## Key Philosophy

> "Fuzzing finds bugs that CRASH. Mythos finds bugs that THINK."

The skill encodes the **process** — how to think about vulnerability discovery systematically. Not a catalog of payloads, but a methodology for understanding what code SHOULD do, finding where reality DIVERGES from intent, and PROVING it with evidence.

## Sources

- **Anthropic**: red.anthropic.com (5 articles), defending-code-reference-harness, official blog, cookbook
- **Industry**: Cloudflare Glasswing, XBOW evaluation, FareedKhan 12-component architecture
- **Benchmarks**: ExploitBench (CMU/Bugcrowd), ExploitGym (Berkeley/MPI), AISI TLO (UK), SCONE-bench
- **Academic**: Co-RedTeam (Google), DrillAgent (UIUC), Refute-or-Promote, VulnSage, Aegis, Phoenix, LogiSec, EnIGMA, DAGVUL, SecPI, Bugonomics (UCL), AgentFlow, Team Atlanta ATLANTIS (DARPA AIxCC winner)
- **Analysis**: System Card PDF, Devansh primary source analysis, MindStudio comparison

## License

For authorized security testing, defensive security, CTF challenges, and educational contexts only.
