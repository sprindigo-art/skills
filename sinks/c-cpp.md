# C/C++ Dangerous Sinks & Patterns

## Memory Corruption
```
memcpy, memmove, memset          — size mismatch, integer overflow in size
strcpy, strcat, strncpy          — no bounds check, off-by-one
sprintf, snprintf, vsprintf      — format string, buffer overflow
gets, scanf("%s")                — unbounded input
alloca                           — stack overflow via large input
realloc                          — use-after-realloc (pointer not updated)
```

## Use-After-Free / Double-Free
```
free() then dereference          — dangling pointer
free() then free()               — double-free
kfree() in kernel                — same patterns
list_del() without nullify       — stale list pointers
refcount underflow               — premature free
```

## Command/Code Injection
```
system(), popen(), execve()      — command injection via unsanitized input
dlopen(), dlsym()                — library injection
```

## Integer Issues
```
(int)(a - b) < 0                 — signed comparison overflow (OpenBSD SACK pattern)
uint16_t from uint32_t           — truncation (FFmpeg sentinel pattern)
size_t from int                  — sign extension
malloc(n * m)                    — integer overflow in multiplication
```

## Kernel-Specific
```
copy_from_user/copy_to_user      — HARDENED_USERCOPY bypass vectors
ioctl handlers                   — type confusion, unchecked size
kmalloc/kfree                    — SLUB exploitation targets
spin_lock without proper order   — deadlock, race condition
rcu_read_lock missing            — use-after-RCU-grace-period
__user pointer dereference       — SMEP bypass needed
```

## File/Path
```
open(), fopen() with user path   — path traversal, symlink race
mktemp(), tmpnam()               — predictable temporary files
realpath() TOCTOU                — resolve then open race
```

## Crypto
```
rand(), srand()                  — predictable randomness
memcmp() for secrets             — timing side-channel
hardcoded keys/IVs               — static secrets
ECB mode usage                   — pattern leakage
```

## Format String
```
printf(user_input)               — format string vuln
syslog(user_input)               — same pattern
fprintf(stderr, user_input)      — same pattern
```

## Race Conditions
```
check-then-use without lock      — TOCTOU
signal handler + global state    — signal race
thread-shared data without mutex — data race → UAF
```

## Kernel Object Patterns (for heap exploitation)
```
struct msg_msg                   — elastic: 48-byte header + variable body, any kmalloc cache
struct pipe_buffer               — 40 bytes, contains function pointer (ops->release)
struct sk_buff                   — dedicated cache, cross-cache required
setxattr + FUSE                  — arbitrary-size controlled allocation with stall
struct cred                      — 192 bytes, target for privilege escalation
struct file                      — contains f_op function pointers
struct tty_struct                — large, contains ops table with function pointers
```
