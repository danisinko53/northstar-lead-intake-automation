# Project overview

**Client:** Northstar Home Services (fictional). **Scope:** lead intake, customer matching, initial assignment, audit and internal email dispatch.

Manual intake risks duplicated leads, inconsistent contact details and missed assignments. The solution receives authenticated JSON requests, validates and normalizes fields, stores customers and inquiries atomically, selects an active service coordinator or flags manual review, and queues a notification for asynchronous delivery.

The supported service types are `plumbing`, `electrical`, `hvac` and `general_repair`. New inquiries start with status `new`; later status values are stored in PostgreSQL. Existing customer contact details are not silently overwritten when a new inquiry differs.

There are two workflows: **NHS-001** processes requests and returns structured HTTP responses; **NHS-002** processes the notification outbox with retry and stale-claim recovery.

For precise interface behavior, see the [API contract](02-api-contract.md). For implementation, see [architecture](03-architecture.md). Requirement-by-requirement evidence is in the [traceability matrix](05-requirements-traceability.md).

**Out of scope:** a CRM user interface, reporting dashboard and real-client production rollout.
