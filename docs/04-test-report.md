# Northstar — Acceptance & Test Report

**Test window:** 2026-10-27 to 2026-10-28 · **Environment:** Docker Compose / n8n 2.45.4 / PostgreSQL 18 / HTTPS test webhook / PowerShell

**Basis:** original client brief **T01–T20**, not the older implementation-test labels T-001–T-023. **PASS** means the reported behavior was demonstrated in the recorded tests; it does not establish production readiness.

## Original brief: T01–T20

| ID | Acceptance scenario | Evidence / observed result | Assessment |
|---|---|---|---|
| T01 | New customer + inquiry | HTTP 201, linked records | PASS |
| T02 | Existing customer, new inquiry | HTTP 201, customer reused | PASS |
| T03 | Exact replay | HTTP 200, existing inquiry returned | PASS |
| T04 | Same ID, changed message | HTTP 409, original inquiry unchanged; DB check `1\|1\|0\|0\|true` | PASS |
| T05 | Missing e-mail | HTTP 422, no new business record | PASS |
| T06 | Invalid e-mail | HTTP 422 validation | PASS |
| T07 | Unknown service type | HTTP 422 validation | PASS |
| T08 | Missing API key | HTTP **403** instead of required **401** | **FAIL — contract deviation** |
| T09 | Incorrect API key | HTTP **403** instead of required **401** | **FAIL — contract deviation** |
| T10 | Malformed JSON | HTTP **422** instead of required **400** | **FAIL — contract deviation** |
| T11 | E-mail capitalization | Two HTTP 201 requests, same customer ID, different inquiry IDs | PASS |
| T12 | Same customer, distinct submission IDs | Two inquiries, one customer, including concurrent test | PASS |
| T13 | Database unavailable | During shutdown: HTTP 500 with safe body; 0 partial records; after restart: HTTP 201 | PASS |
| T14 | Concurrent identical submissions | 20 requests: one created, 19 duplicate; one inquiry persisted | PASS |
| T15 | Routing rule | Service-specific coordinator saved and returned | PASS for tested routes |
| T16 | Conflicting phone | Existing customer retained; submitted phone on inquiry; discrepancy flag true | PASS |
| T17 | Unauthorized valid payload | HTTP 403, `customer_count=0`, `inquiry_count=0` | PASS (business-integrity requirement) |
| T18 | SQL-like text | HTTP 201; `message_preserved=t`; `customers_table_exists=t` | PASS |
| T19 | No active route | Inquiry saved, `assigned_team=NULL`, manual review true | PASS |
| T20 | Query successful audit history | Accepted/customer/inquiry/assignment events observed | PASS for inspected submission |

**Acceptance conclusion:** 17 of 20 behavioral test scenarios have passing evidence, while **T08, T09 and T10 remain nonconformant** to the original required HTTP statuses. This tally does not replace checking all response schemas, edge cases, or the required automated test suite.

## Supporting integration and reliability tests

| Area | Recorded evidence |
|---|---|
| Transaction rollback | Invalid inquiry service type rolled back customer insert (`0` customer, `0` inquiry) |
| Repeated ID replay | Persisted identifiers and `created_at` stable; current stored inquiry `status` returned |
| Existing customer concurrency | Two different submission IDs with same normalized e-mail: two created inquiries, one customer (`1\|2\|2`) |
| Validation error logging | HTTP 422 response, `VALIDATION_FAILED` audit event, metadata without source PII |
| Processing error logging | Injected DB error gave HTTP 500 and `PROCESSING_FAILED` audit event; original query restored |
| Team routing fallback | Disabled routing in rollback transaction; inquiry preserved and manually flagged |
| Notification outbox | One pending queue record on create, none on duplicate; transaction rolled back after test |
| E-mail dispatcher | Gmail message received; outbox `sent`, attempt count 1 |
| Failure/retry | Simulated Gmail failure → `failed`, `GMAIL_SEND_FAILED`, retry scheduled; subsequent successful send verified (attempt count 2) |
| Stale recovery | Stale `processing` job reset; recovery procedure tested |
| Database permissions | `northstar_app` restricted, tested for function execution and insert; no DDL/customer DELETE capability |
| Function permissions | `PUBLIC EXECUTE` removed for three Northstar functions; app access retained |
| Fresh database setup | All 21 SQL migrations applied on separate PostgreSQL 18; 5 tables, 3 functions, 1 trigger, app role; test container removed |
| Injection safety | Query parameters used in inspected n8n SQL nodes; SQL-like input stored verbatim |

Older development IDs **T-001–T-023** covered validation variants, transaction rollback, and 2-/20-request concurrency checks. Their numbering was **internal to development**, not the client's T01–T20; their successful findings are consolidated above rather than reproduced as 23 repetitive sections.

## Gaps and release blockers

1. **HTTP behavior:** make unauthorized missing/incorrect key responses conform to required **401**, malformed JSON to **400**, and retest from the client. Current **403/422** behavior is a documented deviation, not a pass.
2. **Error payload conformance:** the brief specifies codes such as `IDEMPOTENCY_CONFLICT` and `INTERNAL_ERROR`; actual workflow error codes differ (`SUBMISSION_CONFLICT`, `INTERNAL_SERVER_ERROR`). Compare all public error bodies against the original contract before claiming strict compliance.
3. **Automated acceptance tests:** the brief requires **T01–T12 and T17–T18 automated**. Individual PowerShell/manual runs and screenshot evidence exist, but a checked-in repeatable automated harness and CI run have **not been demonstrated**. Record this as incomplete.
4. **Workflow reproducibility:** the sanitised exports require credential binding, scheduling/activation, and an authorized Gmail destination after import. A full fresh-n8n import and end-to-end run have not been demonstrated.
5. **Operational readiness:** production monitoring, abuse prevention/rate limits, retention/privacy policy, backup restoration, and security review remain out of scope of these successful development tests.

## Test methodology and boundaries

Tests were run on a controlled development system using PowerShell HTTP requests and PostgreSQL queries. Selected database tests used `BEGIN`/`ROLLBACK` to avoid persistent fixtures. Other end-to-end API tests created intentional test inquiries and queued notifications. The 20-request concurrency result describes the tested workload; it is not a sustained-load benchmark.

T13 used controlled PostgreSQL shutdown/restart, confirmed the generic 500 response and zero partial records, and then verified new lead processing after recovery. Gmail sending was verified against a real test mailbox, but a notification provider outage can still cause duplicate mail in a send/acknowledgement failure window.

**Status:** credible development portfolio demonstration, **not strict acceptance-complete** until the listed contract and automated-test gaps are addressed.
