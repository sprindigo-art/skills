#!/usr/bin/env bash
# ============================================================================
# MYTHOS METHODOLOGY ENFORCEMENT HOOK v3.0
# Event: Stop (fires at END of every turn)
# Exit 2 = FORCE model to continue (cannot stop until violations resolved)
# Exit 0 = Clean pass (model may stop)
#
# 16 CHECKS covering:
#   E1-E9, Pipeline Stages, Memory Integration, Pathology Detection (6),
#   Academic Research R1-R16, Harness H1-H9, MCP Integration
#
# LIMITATIONS (reasoning patterns — enforced by skill instructions, NOT hook):
#   H4 Impossible conditions, R5 Dialectical, R6 Contracts, R7 CWE-Systematic,
#   R9 Reductio, R10-R12 Cross-family, R14 Constraint-guided, Worker Roles
# ============================================================================

set -uo pipefail

INPUT=$(cat)

TRANSCRIPT=$(echo "$INPUT" | jq -r '
  .transcript // [] | .[-12:] |
  map(select(.role == "assistant")) |
  map(if type == "object" then (.content // (.message.content // "")) else "" end) |
  join(" ")
' 2>/dev/null || echo "")

TOOL_CALLS=$(echo "$INPUT" | jq -r '
  .transcript // [] | .[-15:] |
  map(select(.role == "tool_result" or .role == "tool_use")) | length
' 2>/dev/null || echo "0")

BLOCKS=""
REMINDERS=""

ci() { echo "$TRANSCRIPT" | grep -ciE "$1" 2>/dev/null || echo "0"; }

# ============================================================================
# CRITICAL BLOCKS (exit 2 — model CANNOT stop)
# ============================================================================

# CHECK 1: WRITEBACK — Finding detected but not saved [Memory Integration]
F=$(ci 'vuln(erable|erability)|exploit.*(success|confirm)|RCE|auth.?bypass|IDOR|shell.obtained|credential|password.found|access.gained|root.obtained|webshell|privesc|reverse.shell|uid=0')
W=$(ci 'memory_upsert|memory_autolog|simpan.*memori|saved to.*section|writeback|disimpan|EXPLOIT section|CREDENTIAL section')
[ "$F" -gt 0 ] && [ "$W" -eq 0 ] && BLOCKS="${BLOCKS}⚠️ WRITEBACK [Memory]: Finding/credential/exploit terdeteksi tapi BELUM disimpan. 1 event = 1 write. WAJIB memory_upsert SEKARANG.\n"

# CHECK 2: PREMATURE CONCLUSION — "not vuln" without evidence [E1, E6]
NV=$(ci 'not vulnerable|tidak vuln|sudah.patch|target.aman|tidak ada celah|no vulnerability|fully.patched|aman dari')
EV=$(ci '15\+.variasi|tested.*variations|exhausted|GAGAL.section|adversarial.self-challenge|semua endpoint|all endpoints|BELUM EXHAUSTED')
[ "$NV" -gt 0 ] && [ "$EV" -eq 0 ] && BLOCKS="${BLOCKS}⚠️ E1 VIOLATION: Claim 'not vulnerable' tanpa evidence exhaustive (15+ variasi, PAHAMI WHY, cek GAGAL, riset MCP). Tulis 'BELUM EXHAUSTED' jika belum selesai.\n"

# CHECK 3: ATTACK WITHOUT RECON — Payload tanpa Layer 1 [E3, Pipeline 1-3]
AT=$(ci 'sqlmap|nuclei -|ffuf -w|hydra|wfuzz|msfconsole|exploit/|webshell.*upload|reverse.shell.*payload')
RC=$(ci 'Layer 1|RECONSTRUCT|threat model|THREAT MODEL|attack surface|endpoint map|JS analysis|trust boundar|Stage [123]')
[ "$AT" -gt 2 ] && [ "$RC" -eq 0 ] && BLOCKS="${BLOCKS}⚠️ E3 VIOLATION: Attack tanpa Layer 1 / Threat Model. STOP — Stage 1-3 dulu (BUILD→RECON→THREAT MODEL) BARU Stage 4 HUNT.\n"

# CHECK 4: SOLILOQUIZING — Claiming results without tool calls [R15, Pathology #6]
CL=$(ci 'saya sudah scan|saya sudah test|berhasil ditemukan|confirmed vulnerable|saya menemukan|exploit berhasil|sudah di-verifikasi')
[ "$CL" -gt 2 ] && [ "$TOOL_CALLS" -lt 3 ] && BLOCKS="${BLOCKS}⚠️ R15 SOLILOQUIZING: Claim results tanpa actual tool calls. STOP — RUN command sebenarnya, BACA output asli.\n"

# CHECK 5: ORACLE MISSING — Claim vuln without mechanical proof [Task Verifier]
VU=$(ci 'vulnerability confirmed|vuln confirmed|celah ditemukan|exploit works|berhasil exploit')
OR=$(ci 'ASan|crash|segfault|SIGSEGV|response diff|behavior change|state change|HTTP 200.*data|balance changed|role changed|oracle|sanitizer|3/3')
[ "$VU" -gt 0 ] && [ "$OR" -eq 0 ] && BLOCKS="${BLOCKS}⚠️ ORACLE VIOLATION [Task Verifier]: Claim vuln tanpa mechanical proof. WAJIB: ASan crash / response diff / observable state change / 3/3 consistency. Reasoning saja = HYPOTHESIS bukan FINDING.\n"

# CHECK 6: FINDING WITHOUT CHAIN — Isolated finding, no chain attempt [E5]
FI=$(ci 'finding|ditemukan.*vuln|confirmed.*bug|celah.*ditemukan')
CH=$(ci 'chain|combine|primitive.*map|HAVE.*NEED|escalat.*impact|gabung.*finding')
[ "$FI" -gt 0 ] && [ "$CH" -eq 0 ] && [ "$FI" -lt 5 ] && BLOCKS="${BLOCKS}⚠️ E5 VIOLATION: Finding terdeteksi tanpa chain attempt. WAJIB: MAP ke primitive → cari gap → CHAIN ke higher impact. Low + Low = Critical chain.\n"

# ============================================================================
# REMINDERS (additionalContext — model reads as context, non-blocking)
# ============================================================================

# CHECK 7: THREAT MODEL MISSING — Hunting tanpa threat model [Pipeline Stage 3]
HU=$(ci 'hypothesis|testing.*endpoint|trying.*payload|Stage 4|HUNT|divergence|scanning for')
TM=$(ci 'threat model|THREAT MODEL|Assets|Trust Boundaries|Entry Points|OPEN QUESTIONS|Shostack')
[ "$HU" -gt 2 ] && [ "$TM" -eq 0 ] && REMINDERS="${REMINDERS}💡 PIPELINE: Hunting tanpa threat model. Stage 3 WAJIB selesai: Assets, Trust Boundaries, Entry Points, Threats, OPEN QUESTIONS.\n"

# CHECK 8: NO MCP RESEARCH — Stuck tanpa riset [MCP Integration]
ST=$(ci 'gagal|failed|blocked|denied|tidak berhasil|not work|timeout|connection refused')
MC=$(ci 'search_web|web_search_exa|perplexity_search|read_url|MCP Jina|MCP Exa|MCP Aura')
[ "$ST" -gt 3 ] && [ "$MC" -eq 0 ] && REMINDERS="${REMINDERS}💡 MCP RESEARCH: Multiple failures tanpa MCP research. WAJIB riset bypass/CVE/technique via Jina/Exa/Aura SEBELUM menyerah.\n"

# CHECK 9: SPRAY WITHOUT HYPOTHESIS — Generic payload [Focused CoT, H5, E9]
SP=$(ci "alert.1.|<script>|' OR 1=1|UNION SELECT|{{7\*7}}|/etc/passwd|\.\./\.\./")
HY=$(ci 'hypothesis|karena.*mungkin|seharusnya|berdasarkan.*analisis|code reading|response.*menunjukkan')
[ "$SP" -gt 3 ] && [ "$HY" -eq 0 ] && REMINDERS="${REMINDERS}💡 FOCUSED CoT: Generic payloads tanpa hypothesis. Specify: WHAT class + WHAT endpoint + WHAT input + WHY this should work.\n"

# CHECK 10: REPEATED FAILURE — Retry tanpa RCA [R13, RCA-FIRST, Pathology STUCK]
RE=$(ci 'trying again|retry|coba lagi|attempt.*lagi|ulangi|same.*approach')
[ "$RE" -gt 2 ] && REMINDERS="${REMINDERS}💡 RCA-FIRST [R13]: Repeated attempts. Diagnosa: salah STRATEGY (hypothesis salah) atau TACTICS (implementation error)? JANGAN retry tanpa RCA.\n"

# CHECK 11: DRIFTING — Switching vuln class without exhausting [E2, Pathology DRIFTING]
DR=$(ci 'let me try.*different|pindah ke|switch to|coba class lain|move on to|pivot to')
EX=$(ci 'min 10|exhausted|10\+ variasi|semua angle|all approaches|5 approach')
[ "$DR" -gt 0 ] && [ "$EX" -eq 0 ] && REMINDERS="${REMINDERS}💡 E2 DRIFTING: Switching vuln class tanpa exhaust current. WAJIB: min 10 variasi + PAHAMI WHY gagal + document learnings SEBELUM pivot.\n"

# CHECK 12: WAF BLOCK SURRENDER — Give up setelah WAF block [E7]
WF=$(ci 'WAF|blocked by|filtered|cloudflare|akamai|mod_security|403 forbidden')
BY=$(ci 'bypass|encoding|double.*encode|unicode|obfuscat|alternative.*payload|smuggl|min 10 bypass')
[ "$WF" -gt 2 ] && [ "$BY" -eq 0 ] && REMINDERS="${REMINDERS}💡 E7: WAF block terdeteksi tanpa bypass attempts. Blocked = INFO tentang filter. WAJIB: infer rule → riset MCP 10+ bypass techniques → iterate.\n"

# CHECK 13: GAGAL CHECK MISSING — Teknik tanpa cek dead_ends [H6, Anti-Repeat]
TE=$(ci 'mencoba|testing|exploit.*attempt|trying.*technique|running.*scan')
GA=$(ci 'GAGAL section|dead.ends|sudah gagal|already failed|cek.*gagal|checked.*failed')
[ "$TE" -gt 3 ] && [ "$GA" -eq 0 ] && REMINDERS="${REMINDERS}💡 H6 FAILURE MEMORY: Techniques tanpa cek GAGAL section. WAJIB: memory_get cek dead_ends SEBELUM coba teknik — jangan ulangi yang sudah gagal.\n"

# CHECK 14: REACHABILITY NOT CHECKED — Finding tanpa trace [Pipeline Stage 6]
CF=$(ci 'confirmed|finding.*confirmed|vulnerability.*confirmed|bug.*confirmed')
TR=$(ci 'reachable|TRACE|attacker.*reach|reachability|from.*attacker.*position|Flaw.*Vulnerability')
[ "$CF" -gt 0 ] && [ "$TR" -eq 0 ] && REMINDERS="${REMINDERS}💡 TRACE [Stage 6]: Finding confirmed tapi reachability belum diverifikasi. Flaw ≠ Vulnerability — WAJIB buktikan attacker BISA reach dari posisi realistic.\n"

# CHECK 15: 5-APPROACH RULE — Kurang dari 5 angles [H7]
AB=$(ci 'not vulnerable.*after|abandon|give up|menyerah|conclud.*secure|no vuln found')
AP=$(ci 'approach [2-5]|angle [2-5]|strategy [2-5]|5 approach|five approach|5 different')
[ "$AB" -gt 0 ] && [ "$AP" -eq 0 ] && REMINDERS="${REMINDERS}💡 H7 5-APPROACH: Concluding tanpa evidence 5 genuinely different approaches. Kurang dari 5 = BELUM EXHAUSTED.\n"

# CHECK 16: PoC SELF-CONTAMINATION — PoC testing itself [R16]
PC=$(ci 'PoC.*works|poc.*success|proof.*concept.*success|exploit.*confirmed.*working')
SC=$(ci 'target.*process|target.*behavior|server.*response|actual.*output|fresh.*environment|3/3.*kali')
[ "$PC" -gt 0 ] && [ "$SC" -eq 0 ] && REMINDERS="${REMINDERS}💡 R16 SELF-CONTAMINATION: PoC success claimed — verify PoC measures TARGET behavior, bukan komputasi diri sendiri. Test di fresh environment.\n"

# ============================================================================
# OUTPUT
# ============================================================================

if [ -n "$REMINDERS" ]; then
    CONTEXT=$(echo -e "$REMINDERS" | sed 's/"/\\"/g' | tr '\n' ' ')
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"Stop\",\"additionalContext\":\"${CONTEXT}\"}}"
fi

if [ -n "$BLOCKS" ]; then
    echo -e "$BLOCKS" >&2
    exit 2
fi

exit 0
