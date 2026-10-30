# Requirements traceability

| ID | Implementation and evidence | Status |
|---|---|---|
| FR-01 | Authenticated POST webhook; `401` verified at public edge; underlying n8n auth behavior differs | Verified at public boundary |
| FR-02 | Field validation and normalization; automated and boundary tests | Verified for tested cases |
| FR-03 | Unique normalized customer email, discrepancy handling; 10 parallel distinct submissions | Verified |
| FR-04 | Unique submission ID, persisted payload identity; duplicate/conflict/concurrency tests | Verified |
| FR-05 | Four configurable routes; missing route stored for manual review with audit | Verified |
| FR-06 | Allowed status constraint; `new` default checked | Verified at DB level |
| FR-07 | Audit events for accepted, created, matched, duplicate, conflict, validation/processing failure and assignment fallback; DB-wide outage logging not durable | Verified on tested paths; outage limitation |
| FR-08 | Structured `401`/`400`/`409`/`422`/`500` handling and transactional safety; `503` branch configuration | Partially verified on live failure paths |

## Original acceptance tests

| IDs | Evidence |
|---|---|
| T01–T12 | Automated **12/12 PASS** |
| T13 | Controlled DB failure and recovery; safe `500`, no partial business data |
| T14 | 20 concurrent identical requests: one new, 19 duplicate |
| T15 | Four routing rules verified |
| T16 | Contact discrepancy retained and flagged |
| T17–T18 | Automated **2/2 PASS**, with DB verification |
| T19 | Missing route/manual review/`ASSIGNMENT_FAILED` verified transactionally |
| T20 | Audit records checked |

## Handover

| Deliverable | Status |
|---|---|
| Two sanitized n8n exports | Complete; isolated import PASS |
| 22 database migrations | Complete; fresh PostgreSQL checks PASS |
| Compose template, Worker source, environment example | Complete; config checks PASS |
| Secret-initialization and migration scripts | Isolated tests PASS; Windows DPAPI-specific |
| API contract, architecture, setup guide | Included in repository |
| Automated suite and test report | Included; 14/14 PASS |
| Full clean deployment including Gmail/Cloudflare | **Not yet demonstrated end-to-end** |
| Recorded demonstration | **Deferred by request** |

Evidence detail belongs in the [test report](04-test-report.md); setup detail belongs in [deployment/README.md](../deployment/README.md).

## Verification interpretation

The grouped T01–T12 and T17–T18 rows above cover all 14 automated tests; they are not missing individual test IDs. Detailed evidence and limitations are maintained in [the acceptance test report](04-test-report.md). The remaining T13–T16 and T19–T20 scenarios are supported by manual or database-level checks as individually described there.

The HTTP `413` body limit and the Cloudflare rate limiting rule are supplemental edge protections. Neither changes the original FR-01–FR-08 business requirements or resolves the accepted fresh-stack end-to-end exception.
