# Northstar Home Services

**Lead Intake & CRM Automation — fictional client portfolio case study**

An n8n + PostgreSQL system that accepts service inquiries, reuses existing customer records, assigns coordinators, records an audit trail, and dispatches Gmail notifications. Built and tested in a Docker-based development environment; **not a production deployment**.

## Business problem and solution

Website inquiries can create duplicate customer profiles, be submitted twice, or go unnoticed. Northstar separates **customers** from **inquiries** and processes each valid submission atomically.

- **NHS-001 — Lead Intake API:** authenticated webhook, field validation, normalized-email matching, idempotency, configurable team routing, manual-review fallback, and structured responses.
- **NHS-002 — Email Notification Dispatcher:** scheduled processing of a PostgreSQL outbox, Gmail sending, delivery-state tracking, retries, and stale-claim recovery.
- **Audit:** records intake outcomes, assignments, failures, and relevant processing events with limited personal information.

## Stack

n8n 2.45.4 · PostgreSQL 18 · Docker Compose · Cloudflare Tunnel · JavaScript · PL/pgSQL · Gmail OAuth2 · PowerShell for verification.

## How it works

```text
Trusted website backend → HTTPS → NHS-001 → PostgreSQL
                                       ├─ customers / inquiries
                                       ├─ service_routing / audit_events
                                       └─ notification_outbox
                                              ↓
                                  NHS-002 scheduled dispatcher
                                              ↓
                                       Gmail notification
```

Routing: `plumbing → PLUMBING_TEAM`, `electrical → ELECTRICAL_TEAM`, `hvac → HVAC_TEAM`, `general_repair → GENERAL_TEAM`. Missing routing keeps the inquiry and flags it for manual review.

## Repository layout

```text
workflows/    Sanitized NHS-001 and NHS-002 n8n JSON exports
migrations/   Numbered PostgreSQL migrations 001–021
docs/         Project brief, API contract, architecture, test evidence
```

## Setup overview

1. Supply your own n8n, PostgreSQL, and HTTPS endpoint configuration; never commit `.env` files or credentials.
2. On a **new PostgreSQL 18 database**, apply `migrations/001_*.sql` through `021_*.sql` **in ascending order**, using the intended database owner role. Migration `020` creates/configures `northstar_app`; its password must be set securely outside version control.
3. Import both files from `workflows/` into n8n. Reconnect PostgreSQL credentials (as `northstar_app`), Header Auth for NHS-001, and Gmail OAuth2 for NHS-002.
4. In NHS-002 set the notification recipient to an authorized real mailbox; `notifications@example.com` is an **export placeholder**, not a live recipient.
5. Confirm webhook URL, schedule, SQL query parameters, and workflow activation before testing.

The published JSON files intentionally **exclude credential references and pinned data**. They are portable templates, not immediately operational imports. The repository may require host-specific Docker configuration; use [System Architecture](docs/03-architecture.md) for configuration details.

## Verification snapshot — 28 October 2026

- New lead **201**, identical retry **200**, conflicting submission **409**, validation **422**, database outage **500**; response content verified for the tested paths.
- Reused customer for differing email capitalization; concurrent identical submissions: **1 created / 19 duplicates** in the tested 20-request run.
- Gmail dispatch and failed-send retry verified; least-privilege database account tested.
- All **21 migrations** applied successfully to an isolated, fresh PostgreSQL 18 instance; temporary instance removed.

**Open API contract deviations:** missing/invalid API key returns **403** instead of required **401**; malformed JSON returns **422** instead of required **400**. These are not acceptance passes. The original brief also requires automated coverage for T01–T12 and T17–T18; a maintainable automated suite has **not yet been demonstrated**. See [Test Report](docs/04-test-report.md).

## Documentation

- [Project Overview](docs/01-project-overview.md) — business objectives and requirements
- [API Contract](docs/02-api-contract.md) — request/response specification and deviations
- [System Architecture](docs/03-architecture.md) — database, workflows, security, deployment notes
- [Test Report](docs/04-test-report.md) — original acceptance tests, observed results, remaining work

## Disclaimer

Northstar Home Services is fictional. The implementation demonstrates a realistic portfolio solution, not a real client engagement or production security certification.
