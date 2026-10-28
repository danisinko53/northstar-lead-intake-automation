# Northstar Home Services — Project Overview

**Type:** Fictional US home-services automation brief · **Implementation:** development/test environment · **Date reviewed:** 2026-10-28

## Problem and goal

Northstar receives plumbing, electrical, HVAC, and general-repair inquiries. Manual intake can produce duplicate customers, lost or repeated requests, inconsistent contact data, and delayed coordinator assignment. The project provides a trusted-backend-facing intake API with durable PostgreSQL storage and operational notifications.

## Delivered system

| Component | Purpose |
|---|---|
| NHS-001 · Lead Intake API | Header-authenticated POST webhook; validate, normalize, persist and respond |
| NHS-002 · Email Notification Dispatcher | Scheduled outbox processing; Gmail delivery, retries, recovery |
| PostgreSQL | Customer matching, atomic inquiries, routing, audit, notification queue |
| Docker / Cloudflare Tunnel | Development infrastructure and external HTTPS access |

## Requirements traceability

| Requirement | Implementation evidence | Status |
|---|---|---|
| FR-01 · Submission API | Authenticated webhook and JSON HTTP responses | Implemented; 401 contract deviation |
| FR-02 · Validation | JavaScript validation and PostgreSQL constraints | Implemented; malformed JSON returns 422, not 400 |
| FR-03 · Customer identification | Unique normalized email, submitted data preserved, discrepancy flag | Tested |
| FR-04 · Idempotency | Unique submission ID, SHA-256 payload identity, advisory lock | Tested incl. concurrent retries |
| FR-05 · Assignment | Configurable `service_routing`; `needs_manual_review` fallback | Tested |
| FR-06 · Inquiry status | Database statuses: `new`, `assigned`, `contacted`, `qualified`, `closed`, `cancelled` | Implemented at database level |
| FR-07 · Audit trail | `audit_events`, processing and validation failure events | Tested for selected paths |
| FR-08 · Error handling | Structured validation/conflict/internal errors, transaction rollback | Tested; HTTP contract exceptions remain |

### Assignment rules

| Service | Coordinator |
|---|---|
| `plumbing` | `PLUMBING_TEAM` |
| `electrical` | `ELECTRICAL_TEAM` |
| `hvac` | `HVAC_TEAM` |
| `general_repair` | `GENERAL_TEAM` |

An inquiry remains stored when no active route exists, with `needs_manual_review = true`. When an existing customer's submitted name or phone differs, the customer profile is not silently overwritten: inquiry values are retained and `has_customer_discrepancy` identifies the mismatch.

## Scope and boundaries

This project covers intake, initial assignment, status storage, audit, and internal e-mail notification dispatch. **A full CRM UI, lead lifecycle management interface, reporting dashboard, and real-customer deployment are outside this initial brief.**

The dispatcher uses a database outbox so lead persistence does not depend on Gmail availability. A successful insert schedules a notification; retries and stale-processing recovery are handled separately.

## Evidence and outstanding acceptance work

The original brief has **20 acceptance tests (T01–T20)**; observed results and known failures are tracked only in the [Test Report](04-test-report.md). Notable checks include two distinct submissions sharing a customer, 20 concurrent identical requests, DB shutdown/recovery, authorization rejection, and injection-like text saved as data.

Remaining before strict contract acceptance: **401 for missing/invalid credentials**, **400 for malformed JSON**, evidence of the brief's required **automated T01–T12/T17–T18 suite**, and final operational/privacy review. A successful clean migration test does not establish production readiness.

See the [API Contract](02-api-contract.md) and [System Architecture](03-architecture.md) for implementation details.
