# Logic Bug Hunting, Mobile Exploitation & Protocol Reverse Engineering

## WEB APPLICATION LOGIC BUG HUNTING (Mythos' Secret Weapon)

### Why Logic Bugs Matter
```
Mythos found:
- Multiple COMPLETE authentication bypasses (unauth → admin)
- Account login bypasses (skip password + 2FA)
- Denial-of-service via data deletion
- Cross-tenant IDOR in multi-tenant apps

Key insight: Logic bugs are NOT memory corruption.
- No crash, no sanitizer detection, no fuzzer can find them
- They exist in the GAP between INTENDED behavior and ACTUAL behavior
- Only SEMANTIC UNDERSTANDING can find them
- This is Mythos' TRUE superpower over traditional tools
```

### Systematic Logic Bug Discovery Protocol
```
FOR each authentication/authorization flow:

STEP 1: MAP THE STATE MACHINE
  - Document every step in the flow (login, register, password reset, 2FA)
  - Identify: what state is expected at each step?
  - Document: what transitions are valid?
  
STEP 2: VIOLATE STEP ORDERING
  - Skip step 2, go directly to step 3 (does it check?)
  - Repeat step 1 twice, skip step 2
  - Send step 3's request with step 1's session
  - Go backwards: step 3 → step 1 → step 3
  
STEP 3: PARAMETER MANIPULATION
  - Remove required parameters (what defaults are used?)
  - Add unexpected parameters (role=admin, is_admin=true)
  - Change IDs (user_id, tenant_id, org_id)
  - Swap token types (access token where refresh expected)
  
STEP 4: RACE CONDITIONS IN BUSINESS LOGIC
  - Send same request simultaneously (double-spend, double-vote)
  - Concurrent state modification (two threads modify same resource)
  - Time-of-check vs time-of-use in multi-step operations
  
STEP 5: BOUNDARY VIOLATIONS
  - Negative quantities (order -1 items → credit?)
  - Zero amounts (transfer $0 → bypass validation → modify recipient?)
  - Maximum values (integer overflow in price calculation)
  - Currency/unit confusion (cents vs dollars, bytes vs KB)
```

### Authentication Bypass Patterns (2025-2026)
```
Pattern 1: Flawed State Machine
  Normal: GET /login → POST /login (creds) → GET /2fa → POST /2fa (code) → GET /dashboard
  Attack: GET /login → POST /login (creds) → GET /dashboard (skip 2FA!)
  Why: Dashboard only checks "is logged in" not "completed 2FA"

Pattern 2: Role Assignment at Registration
  Normal: POST /register {username, password} → role="user" assigned by server
  Attack: POST /register {username, password, role: "admin"}
  Why: Server accepts client-supplied role without validation

Pattern 3: Password Reset Token Reuse
  Normal: Request reset → get token → use token → token invalidated
  Attack: Request reset → get token → use token → use SAME token again
  Why: Token not invalidated after use, or invalidation is async

Pattern 4: Multi-Tenant ID Manipulation (IDOR)
  Normal: GET /api/data?tenant_id=MY_TENANT
  Attack: GET /api/data?tenant_id=OTHER_TENANT
  Why: Authorization checks user authentication but not tenant membership

Pattern 5: OAuth Redirect Manipulation
  Normal: redirect_uri=https://app.com/callback
  Attack: redirect_uri=https://app.com/callback/../../../attacker.com
  Why: Partial URI matching or path normalization after validation

Pattern 6: JWT Claim Manipulation (after signature bypass)
  Normal: {"sub": "user123", "role": "user"}
  Attack: {"sub": "admin", "role": "admin"} (with algorithm=none or key confusion)
  Why: Signature verification bypassed via algorithm confusion

Pattern 7: API Version Inconsistency
  Normal: /api/v2/admin (requires auth)
  Attack: /api/v1/admin (no auth check on legacy version!)
  Why: Legacy endpoints not decommissioned, different middleware stacks

Pattern 8: HTTP Verb Tampering
  Normal: GET /admin → 403 Forbidden
  Attack: POST /admin or OPTIONS /admin or HEAD /admin → 200 OK
  Why: ACL only checks GET method, other verbs pass through
```

### Business Logic Exploitation Patterns
```
E-Commerce:
  - Negative quantity → refund to attacker balance
  - Coupon reuse (race condition: apply same code simultaneously)
  - Price manipulation (modify price in client-side request)
  - Currency rounding exploitation (0.001 * 1000000 iterations = profit)

Financial:
  - Transfer to self → balance increase (rounding error accumulation)
  - Simultaneous withdraw from same account (race condition → double spend)
  - Cross-account operations with incorrect ownership check
  - Transaction limit bypass via splitting into smaller amounts

Subscription/Access:
  - Trial reset (new email, same payment method → infinite trial)
  - Plan downgrade keeps premium features (cached permissions)
  - Referral abuse (self-referral via different session)
  - License check bypass (offline grace period exploitation)
```

---

## MOBILE EXPLOITATION (Android & iOS — 2025-2026)

### Android Kernel Exploitation
```
Attack surface:
  - GPU drivers (Qualcomm Adreno, ARM Mali, Google Tensor)
  - Media codecs (Dolby, video decoders)
  - Binder IPC (Android-specific inter-process communication)
  - Filesystem drivers (F2FS, ext4 in kernel)
  - USB/Charging drivers (via physical access)

Current patterns (2025-2026):
  CVE-2025-21479 (Mali GPU): UAF → physical memory R/W via GPU → PTE manipulation → SELinux disable → root
  CVE-2026-21385 (Qualcomm display): Integer overflow → memory corruption → 235 chipsets affected
  Dolby 0-click (CVE-2025-54957): media processing → code execution without user interaction
  
Exploitation chain (typical):
  1. Trigger vulnerability (GPU driver UAF, media codec overflow)
  2. Get kernel memory R/W primitive (via GPU physical memory access or PTE corruption)
  3. Bypass KASLR (scan predictable kernel memory ranges)
  4. Disable SELinux (flip enforcing → permissive in kernel memory)
  5. Hijack init process (remap shared libraries via physical memory access)
  6. Execute payload as init (full system access, root shell)
  
Key challenge: SELinux prevents even root from doing most things
  Solution: Disable SELinux in kernel memory, OR hijack a privileged process (init, zygote)
```

### iOS Exploitation (PAC, SPTM, PPL)
```
iOS mitigations hierarchy:
  - PAC (Pointer Authentication): Cryptographic signature on code pointers
  - SPTM (Secure Page Table Monitor): Page tables managed at EL2 (hypervisor)
  - PPL (Page Protection Layer): Kernel code integrity
  - KTRR/KPP: Kernel text/data read-only enforcement

PAC Bypass (Predator spyware pattern):
  1. Get kernel R/W primitive
  2. Scan JavaScriptCore framework for "PAC signing gadget" (JSC::JSArrayBuffer::isShared)
  3. Use existing Apple code to sign arbitrary pointers
  4. Pre-compute signing cache for all needed addresses
  5. Now can redirect any PAC-protected function pointer

iOS exploit chain (DarkSword 2025-2026, 6 stages):
  Stage 1: Initial code execution (Safari/iMessage/media parsing)
  Stage 2: Sandbox escape (IPC/Mach port manipulation)
  Stage 3: User-space privilege escalation
  Stage 4: Kernel process compromise (mediaplaybackd, etc.)
  Stage 5: Kernel memory corruption (driver race condition → arbitrary R/W)
  Stage 6: Persistence and surveillance payload installation
  
Post-SPTM (A15+): Page table manipulation no longer works from EL1
  Must find EL2 vulnerabilities or alternative primitives
```

### BootROM / Bootloader Exploitation
```
CVE-2026-25262 (Qualcomm BootROM):
  - Vulnerability in Sahara protocol (USB upload to device)
  - Runs BEFORE any OS boots, before any security controls
  - Affects: MDM9x07, MDM9x45, MDM9x65, MSM8909, MSM8916, MSM8952, SDX50
  - Cannot be patched via software update (burned into silicon)
  - Physical access required (USB connection in EDL mode)
  
Exploitation:
  1. Force device into EDL mode (specific key combo or command)
  2. Connect via USB, device enters Sahara protocol
  3. Send crafted Sahara packets exploiting buffer overflow in PBL
  4. Execute arbitrary code at highest privilege level (EL3/secure world)
  5. Bypass locked bootloader, secure boot, everything

Qualcomm universal root (Magica project, 2026):
  - Works on ALL Qualcomm devices with January 2026 patch or older
  - Enables root even with permanently locked bootloader
  - Requires SELinux permissive mode first (achieved via fastboot)
  - Based on BootROM-level exploit chain
```

### Android Attack from Compromised App/Shell
```
Privilege escalation paths:
  1. Kernel exploit (GPU/media/binder) → root
  2. Binder service exploitation → gain capabilities of system services
  3. SELinux policy bypass → access otherwise restricted resources
  4. Intent/ContentProvider abuse → cross-app data access

Post-exploitation:
  - Credential access: /data/misc/wifi/WifiConfigStore.xml (WiFi passwords)
  - Message interception: Content providers for SMS/calls
  - Camera/Mic access: Bypass permission checks with system UID
  - Keylogger: Accessibility service injection or input method abuse
```

---

## PROTOCOL REVERSE ENGINEERING (From Traffic Only)

### Methodology (When No Documentation Available)
```
STEP 1: CAPTURE TRAFFIC
  - tcpdump / Wireshark on target interface
  - Capture multiple sessions with different operations
  - Label captures by action performed (login, data request, command, etc.)

STEP 2: IDENTIFY STRUCTURE
  Determine if protocol is:
  - Text-based: ASCII readable (HTTP, SMTP, FTP-like)
  - Binary: Non-printable characters, fixed-width fields
  - Hybrid: Text headers + binary body (HTTP with binary payload)
  - TLS-wrapped: Need to decrypt first (key extraction or MITM)

STEP 3: BINARY PROTOCOL FIELD INFERENCE
  For binary protocols:
  a) Align multiple messages of SAME type (same request, different parameters)
  b) Compare byte-by-byte → static bytes = header/type, changing bytes = parameters
  c) Identify:
     - Magic bytes (protocol signature, usually first 2-4 bytes)
     - Length fields (look for values that match remaining packet size)
     - Type/opcode fields (different values for different operations)
     - Sequence numbers (incrementing values)
     - Checksums (last 2-4 bytes, changes with content)
  d) Use entropy analysis: high entropy = encrypted/compressed, low = structured data

STEP 4: STATE MACHINE RECONSTRUCTION
  - Record request-response pairs in order
  - Identify: what request can follow what response?
  - Map: authentication sequence, session establishment, data transfer phases
  - Find: can we skip states? Send unexpected messages in wrong state?

STEP 5: FUZZING THE PROTOCOL
  Once structure understood:
  - Mutate type fields (send unknown opcodes → observe error handling)
  - Overflow length fields (claim more data than provided)
  - Replay old messages (find stateless handlers)
  - Send malformed messages (truncated, oversized, invalid encoding)
```

### Techniques for Unknown Binary Protocols
```
Frequency analysis:
  - Count byte frequency per position → non-uniform = structured
  - Position 0-3 with very few unique values = type/magic field
  - Position with exactly 2 or 4 byte values matching packet length = length field

Diff-based inference:
  - Send same command with parameter "AAAA" then "BBBB"
  - Diff the raw bytes → changed positions = parameter encoding
  - Repeat with different lengths → find length-prefix patterns

Response correlation:
  - Request type X always gets response type Y
  - Error responses often have consistent structure (error code + message)
  - Map request-response pairs to build protocol grammar

Endianness detection:
  - Send value 0x0100 (256 in big-endian, 1 in little-endian)
  - Check server response/behavior for correct interpretation
  - Most network protocols: big-endian (network byte order)
  - Most embedded/x86: little-endian

Tool-assisted:
  - Netzob: Automated protocol inference from traffic
  - BinPRE: Deep learning for field inference
  - TransFielder (2026): Transfer learning for protocol RE
  - Wireshark Lua dissectors: Write custom parsers as you discover structure
```

### ICS/SCADA Protocol Patterns (Cooling Tower Context)
```
Common ICS protocols (often proprietary variants):
  - Modbus TCP: Read/Write to PLC registers (coils, holding registers)
  - S7comm: Siemens PLC communication
  - EtherNet/IP + CIP: Rockwell/Allen-Bradley
  - DNP3: Distribution Network Protocol (power grid)
  - OPC UA: Modern industrial communication

Attack patterns:
  1. Read PLC memory → understand process state
  2. Write to holding registers → modify setpoints
  3. Write to coils → toggle outputs directly
  4. Replay captured commands → repeat previous operations
  5. Craft custom commands → force dangerous states

Key insight from AISI (why models struggle here):
  - Protocol documentation often proprietary/unavailable
  - Must deduce structure from traffic capture ALONE
  - Requires sustained reasoning over many steps
  - Information from step 1 needed in step 7 (long-horizon dependency)
  - Our Memory system helps: save protocol structure as discovered
```

---

## EXPLOIT RELIABILITY ENGINEERING (Making Exploits 95%+)

### Why Mythos Builds Deterministic Exploits
```
Human exploit: spray heap, hope allocation lands → ~60% reliability
Mythos exploit: precise control, verify each step → ~95% reliability

ExploitBench insight: Mythos built STABLE exploit for CVE-2023-6702
  where public exploits were probabilistic and uncontrolled.
  "I have discussed this approach with the original exploit author
   who dismissed it due to complexity. Mythos executed it cleanly."
```

### Techniques for Reliability
```
1. HEAP STABILIZATION
   - Drain allocator caches to known state before exploitation
   - Use large spray to statistically guarantee placement
   - Pin to specific CPU (sched_setaffinity) for deterministic SLUB behavior
   - Trigger GC / allocation cleanup before critical operations

2. VERIFICATION AT EACH STEP
   - After spray: verify target object is in expected position
   - After overwrite: read back corrupted value before using it
   - After KASLR bypass: validate leaked pointer is in expected range
   - If verification fails: retry from last known-good state

3. TIMING CONTROL
   - userfaultfd: freeze thread at exact page fault → deterministic race
   - FUSE: filesystem operation blocks indefinitely → control scheduling
   - perf_event (EXPRACE): interrupt at precise instruction count
   - Sleep/nanosleep: allow other threads to reach expected state

4. FAILURE RECOVERY
   - Catch signals (SIGSEGV/SIGBUS) → retry with different parameters
   - Exception handling around dangerous operations
   - Multiple retry attempts with slight variations
   - Graceful degradation: if full exploit fails, try simpler variant

5. ENVIRONMENT NORMALIZATION
   - Kill interfering processes before exploitation
   - Clear filesystem caches that might cause unexpected allocations
   - Set CPU affinity to single core (eliminate SMP race conditions)
   - Disable automatic background tasks that allocate memory

6. MULTI-ROUND APPROACH (FreeBSD NFS pattern)
   - Split complex exploit across multiple attempts
   - Each attempt builds on state from previous
   - If any step fails: clean up and retry JUST that step
   - Don't restart from scratch on partial failure
```
