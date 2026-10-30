# Acceptance test report

**Environment:** n8n 2.45.4, PostgreSQL 18, Docker, HTTPS; development testing on 27–28 October 2026.

## Original client scenarios

| Tests | Verified behavior | Evidence |
|---|---|---|
| T01–T04 | New/existing customer, exact replay and conflict | Automated PASS |
| T05–T07 | Missing/invalid email and unknown service rejected | Automated PASS |
| T08–T10 | Public-edge missing/invalid key `401`; malformed JSON `400` | Automated PASS; underlying n8n auth behavior may differ |
| T11–T12 | Case-insensitive customer match and distinct inquiries | Automated PASS |
| T13 | Controlled database failure: no partial business records; recovery successful | Earlier manual test; response `500` in that test |
| T14 | Concurrent identical requests | 1 created + 19 duplicate (20 requests) |
| T15–T16 | Four service routes; contact discrepancy preserved | Integration PASS |
| T17–T18 | Unauthorized request leaves no business writes; SQL-like text stored as data | Automated PASS, DB checks |
| T19 | Missing route: `assigned_team = NULL`, manual review and failure audit | Transactional database test PASS; rolled back |
| T20 | Accepted/customer/inquiry/assignment audit events | Database evidence PASS |

**Automated suite:** `tests/Run-NorthstarAcceptance.ps1` — **14/14 PASS** (T01–T12, T17–T18). Additional boundary checks: **13/13 PASS**. Separate concurrency test: 10 distinct submissions sharing one email → 10 × `201`, one customer and 10 inquiries.

**Infrastructure:** 22/22 migrations applied to an empty PostgreSQL 18 database; application-role permission checks passed, including a different database name after the portability fix. Both sanitized workflows imported into isolated n8n (22 nodes total, both inactive). New-installation secret initializer tested in isolated PostgreSQL: generated API key and app password accepted; cleanup confirmed.

**Notification dispatcher:** prior Gmail delivery, retry and stale-claim recovery tests passed. It was not reactivated for the final API regression run.

## Remaining verification / delivery

- Full fresh-stack n8n + PostgreSQL + Gmail + Cloudflare **end-to-end configuration** has not been demonstrated together; isolated component checks are not a substitute.
- The latest exported `503` authentication-database-error branch is structurally verified, but the earlier controlled outage exercise returned `500` on its tested error path.
- Recorded demo: **deferred by request**.
- These tests do not establish production readiness or exactly-once email delivery.

## Audit remediation verification (30 October 2026)

- F-01: Acceptance runner supports an explicit Compose file and optional environment file; 14/14 tests passed when executed outside the repository directory against the existing development stack.
- F-02: The six-node NHS-002 export was imported into isolated n8n and confirmed inactive.
- F-03: Success-response schema assertions were added to the automated acceptance suite; regression passed.
- F-04: Validation-failure audit SQL uses a parameterized submission UUID when valid. The repository expression was corrected; full audit correlation for every invalid-input case was not independently demonstrated.
- F-05: Dispatcher SQL and node references were inspected. At-least-once delivery can repeat mail after Gmail acceptance and before the sent-state commit; the acceptance brief does not demand exactly-once delivery. The specific acknowledgment-loss window was not fault-injected.
- F-06: Restricted database role reviewed. Direct application write grants remain because existing operations use invoker privileges; no privilege-hardening migration was applied.
- F-07: Live HTTP `413`/`PAYLOAD_TOO_LARGE` and `400`/`BAD_JSON` regressions passed. Cloudflare rate limiting rule deployed active, but a threshold-crossing block test has not been performed.
- F-08: HTTP `503` and `500` error branches inspected. Failed execution storage kept disabled for data minimization; complete PostgreSQL outage logging remains unavailable. Persistent diagnostics during a complete PostgreSQL outage are not guaranteed.
- F-09: Four timestamp boundary HTTP tests passed: leap-day and `+13:59` accepted (`201`); invalid leap-day and `+14:30` rejected (`422`).

Evidence boundaries: T01–T12 and T17–T18 are automated HTTP/DB acceptance checks. T13–T16, T19 and T20 have separately described manual or database-level evidence; T19 is not claimed as a full HTTP end-to-end test. The recorded demo and complete fresh-stack end-to-end deployment remain accepted exceptions.
