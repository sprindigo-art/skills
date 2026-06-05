# Thinking Triggers — Automatic Questions Per Endpoint Type

These are the SPECIFIC mental questions expert pentesters ask AUTOMATICALLY
when they encounter each type of endpoint/feature. Encode these as REFLEXES —
ask them EVERY TIME without needing to be reminded.

Source: 50+ expert sources, bug bounty playbooks, and Mythos reasoning analysis.

---

## TRIGGER 1: See {id} or identifier in URL/parameter

```
IMMEDIATELY ASK:
- Whose ID is this? Can I change it to another user's? (IDOR)
- Is it sequential? Can I enumerate? (user enumeration)
- Does response DIFFER between valid and invalid IDs? (oracle)
- Can I access WRITE operations on someone else's ID? (privilege escalation)
- Is there an admin/system ID I can guess? (vertical escalation)
```

## TRIGGER 2: See multi-step flow (checkout, registration, verification)

```
IMMEDIATELY ASK:
- What if I SKIP step 2 and go directly to step 4? (state bypass)
- What if I GO BACKWARDS from step 3 to step 1? (state reset)
- What if I REPLAY the final step from clean session? (token reuse)
- What if I complete steps OUT OF ORDER? (sequence break)
- What state does user DEFAULT to if step is skipped? (implicit role)
- Can I access post-completion features BEFORE completing? (premature access)
```

## TRIGGER 3: See parameter with value that looks like client-set

```
IMMEDIATELY ASK:
- Should the SERVER trust this value from the client? (trust violation)
- What if I change price/amount to 0? To negative? (price manipulation)
- What if I add role=admin to the request body? (mass assignment)
- What if I change quantity to 999999? To -1? (integer boundary)
- What if I change currency field? (currency confusion)
- Is this value used server-side without re-validation? (blind trust)
```

## TRIGGER 4: See authentication mechanism

```
IMMEDIATELY ASK:
- Which COMPONENT actually decides identity is trusted? (trust chain)
- Are there PARALLEL auth mechanisms (cookie AND JWT)? Remove one — still works? (fallback auth)
- What if I remove ALL auth headers? Which endpoints still respond? (missing auth)
- What if I send EMPTY or MALFORMED token? (validation failure)
- Does role-selector/MFA have DEFAULT if step skipped? (state machine)
- Can I access endpoints by adding them to a LOW-priv session? (vertical escalation)
- Is there DIFFERENT auth for API vs web UI for SAME resource? (inconsistency)
```

## TRIGGER 5: See password reset / account recovery flow

```
IMMEDIATELY ASK:
- Is the token re-validated on FINAL submission? Or only at start? (one-time validation)
- Can I change the target user AFTER token validation step? (parameter swap)
- Can I use MY valid token to reset ANOTHER user's password? (token-user binding)
- Is the token invalidated after use? Can I reuse it? (token reuse)
- Can I trigger reset for two accounts simultaneously? (race condition)
- Does the reset link leak via Referer header? (token leakage)
```

## TRIGGER 6: See payment/transaction/credit system

```
IMMEDIATELY ASK:
- What if I send NEGATIVE amount? (credit injection)
- What if I change price AFTER validation but BEFORE charge? (TOCTOU)
- Can I apply same coupon MULTIPLE TIMES simultaneously? (race condition)
- What if I cancel AFTER refund processed but BEFORE debit? (double-spend)
- What if I change currency in the request? (currency conversion abuse)
- Is the final price calculated CLIENT-side? Can I intercept? (price tampering)
- Can I buy item at promotional price after promo expired? (time boundary)
```

## TRIGGER 7: See file upload feature

```
IMMEDIATELY ASK:
- What extensions actually EXECUTE vs serve static? (.php, .jsp, .asp, .html)
- Is validation on file EXTENSION, MIME type, or CONTENT? (bypass target)
- Can I upload .html for stored XSS? .svg with JS? (content-type abuse)
- Where is file STORED? Same domain? Subdomain? (scope of execution)
- Can I control the FILENAME? Path traversal in filename? (path manipulation)
- Is there race between upload and validation? (upload-then-delete race)
- Can file be accessed WITHOUT auth after upload? (auth-free file access)
```

## TRIGGER 8: See API endpoint accepting URL/hostname parameter

```
IMMEDIATELY ASK:
- Can I point it to internal services? (SSRF)
- What about 127.0.0.1, localhost, 169.254.169.254? (metadata)
- Does it follow REDIRECTS? Can I redirect to internal? (open redirect → SSRF)
- Can I use DNS rebinding? (point to internal after first resolution)
- What protocols does it support? file://, gopher://, dict://? (protocol smuggling)
- Is there a whitelist? Can I bypass with @ or #? (URL parsing confusion)
```

## TRIGGER 9: See error message or non-standard response

```
IMMEDIATELY ASK:
- Does it reveal INTERNAL PATH or technology? (info disclosure)
- Does it reveal DATABASE STRUCTURE or query? (SQL error)
- Does it differ for VALID vs INVALID input in meaningful way? (oracle)
- Does error occur at DIFFERENT TIMING for different inputs? (timing oracle)
- Can I trigger DIFFERENT errors by varying input? (path mapping)
- Does it reveal STACK TRACE or framework version? (tech fingerprint)
```

## TRIGGER 10: See any endpoint with multiple user roles

```
IMMEDIATELY ASK:
- Can LOWER role access HIGHER role's endpoints directly? (vertical)
- Can SAME role access DIFFERENT user's data? (horizontal)
- Are role checks in MIDDLEWARE or per-ENDPOINT? (inconsistency)
- What if I add/change role parameter in request? (mass assignment)
- Is authorization checked on EVERY request or only on login? (session fixation)
- What about API endpoints behind the UI — same auth? (API vs UI gap)
```

---

## TOXIC COMBINATION FRAMEWORK (from Hemanth Gorijala)

```
Phase 1: INFORMATION — "What does app teach me I shouldn't know?"
  → user IDs leaked, endpoints exposed, version disclosed

Phase 2: ACCESS — "What data can I access that isn't mine?"
  → IDOR on read endpoints with leaked IDs
  
Phase 3: MODIFY — "Can I WRITE with that same identifier?"
  → Same ID that gave me read → try on write/delete/update endpoints
  
Phase 4: ESCALATE — "Does this endpoint even need auth?"
  → Remove all auth headers → test every endpoint unauthenticated

Each phase OUTPUT → next phase INPUT.
Low + Medium + High findings CHAIN into Critical.
```

---

## STATE MACHINE ATTACK CHECKLIST

```
FOR EVERY MULTI-STEP FLOW:
1. MAP: Document every step and state transition (S1→S2→S3→Done)
2. SKIP: Try accessing final state without intermediate steps
3. REVERSE: Try going S3→S2→S1 (backwards)
4. REPLAY: Complete flow once, replay final request from clean session
5. PARALLEL: Send step-completing requests simultaneously (race)
6. MODIFY: Change state identifiers mid-flow (switch user/target)
7. DEFAULT: What state does user get if step is dropped/fails?
8. INCOMPLETE: Start flow, don't finish — what state persists?

"Draw the state machine. For every state pair, ask 'can the user 
FORCE this transition?' The unintended yes-es are the bugs."
— RingSafe Module 15
```
