# Web Language Dangerous Sinks & Patterns

## PHP
```
# Code Execution
eval(), assert(), preg_replace('/e')
create_function(), call_user_func()
include/require (with user path)
${$var} variable variables

# Deserialization (POP chains)
unserialize()                    — gadget chains: SwiftMailer, Monolog, Guzzle, Laravel
phar:// wrapper                  — triggers deserialization on file ops
__wakeup(), __destruct()         — magic methods = gadget entry points
__toString() in render context   — object injection → file write

# Command Injection
system(), exec(), passthru(), shell_exec()
popen(), proc_open()
backtick operator ``

# File Operations
file_get_contents(user_url)      — SSRF
file_put_contents(user_path)     — arbitrary file write
move_uploaded_file()             — extension bypass
include(user_input)              — LFI/RFI

# SQL
mysql_query($user_input)         — SQLi
PDO without prepared statements

# Type Juggling
== vs ===                        — loose comparison bypass
0 == "string" → true
"0e123" == "0e456" → true        — magic hash collision
in_array() without strict        — type coercion
```

## Python
```
# Code Execution
eval(), exec(), compile()
os.system(), subprocess.Popen(shell=True)
__import__()

# Deserialization
pickle.loads()                   — arbitrary code execution
yaml.load() (without SafeLoader) — same via !!python/object
jsonpickle.decode()
shelve module

# Template Injection (SSTI)
jinja2.Template(user_input)      — {{ config.__class__.__mro__[1].__subclasses__() }}
mako.template.Template()
tornado templates
f-string with user input (rare but possible)

# Path Traversal
open(user_path)
os.path.join(base, user_input)   — absolute path bypass: /etc/passwd
send_file(user_input)
shutil operations with user paths

# SSRF
requests.get(user_url)
urllib.request.urlopen()
httpx.get()
```

## Java
```
# Deserialization (Gadget Chains)
ObjectInputStream.readObject()   — Chains: CommonsCollections, CommonsBeanutils, ROME, C3P0
XMLDecoder                       — XML deserialization RCE
Hessian2Input.readObject()       — ProxyLazyValue chain, RESIN chain
Kryo, FST, XStream              — various chains
SnakeYAML Constructor           — !!javax.script.ScriptEngineManager

# JNDI Injection (Log4Shell pattern)
InitialContext.lookup(user)      — LDAP/RMI → class loading → RCE
javax.naming.Context
JMX remote bean loading

# Expression Language
SpEL: #{user_input}              — Spring Expression Language RCE
OGNL: %{user_input}             — Struts2 RCE pattern
EL: ${user_input}               — JSP Expression Language
MVEL, JBoss EL

# Template Injection
Thymeleaf: __${user}__          — preprocessor → SpEL → RCE (CVE-2026-40478 TAB bypass)
Freemarker: <#assign>           — built-in bypass via ?new()
Velocity: #set($x=...)          — class loading

# SQL/Command
PreparedStatement with concat    — SQLi despite "using prepared statements"
Runtime.exec(user_input)
ProcessBuilder
```

## JavaScript/TypeScript (Node.js)
```
# Code Execution
eval(), Function()
vm.runInNewContext()             — sandbox escape possible
child_process.exec(user_input)
require(user_input)             — module injection

# Prototype Pollution
Object.assign(target, user)      — __proto__ pollution
lodash.merge/set/defaultsDeep
jQuery.extend(deep)
JSON.parse(user) → object spread
# Impact: RCE via template engines (handlebars), child_process gadgets

# Template Injection
ejs: <%- user %>                 — SSTI
pug/jade: #{user}
handlebars: {{user}} + proto pollution → RCE
nunjucks: {{ user }}

# SSRF/File
axios.get(user_url), node-fetch()
fs.readFile(user_path)
path.join() with .. traversal

# Deserialization
node-serialize                   — IIFE execution
funcster
js-yaml (custom types)
```

## GraphQL Specific
```
# Introspection
{ __schema { types { name fields { name } } } }   — full schema disclosure

# Batching for Auth Bypass
[{query: "mutation { login(...) }"}, {query: "mutation { login(...) }"}]
# Bypass rate limiting — 100 login attempts in 1 request

# Nested Query DoS
{ user { posts { comments { author { posts { comments { ... } } } } } } }

# Field Suggestion / Alias Abuse
{ a1: sensitiveField, a2: sensitiveField, ... }    — rate limit bypass

# Directive Injection
@include(if: $condition) manipulation
```

## JWT/Auth Patterns
```
# Algorithm Confusion
alg: "none"                      — signature bypass
RS256 → HS256                    — use public key as HMAC secret
# Header Injection
jku/x5u/jwk header              — attacker-controlled key
kid: "../../key"                 — path traversal in key lookup
kid: "' OR 1=1--"              — SQL injection in key lookup
# Claim Manipulation
iss/sub claim impersonation
exp removal/far-future
role/scope elevation
```
