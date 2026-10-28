
# Northstar Home Services
## Lead Intake & CRM Automation

**Project ID:** NHS-001  
**Project Type:** Workflow Automation / API Integration  
**Platform:** n8n  
**Database:** PostgreSQL 18  
**Status:** Implemented and tested in a development environment

---

## 1. Project Background

Northstar Home Services is a fictional US-based
home services company that receives customer
inquiries for plumbing, electrical, HVAC, and
general repair services.

The company needs a reliable system to receive
incoming leads, validate customer information,
prevent duplicate submissions, and store
customer inquiries in a centralized database.

## 2. Business Problem

Without an automated intake process, the
company risks:

- Losing incoming customer inquiries.
- Creating duplicate customer records.
- Processing the same form submission multiple times.
- Storing incomplete or invalid customer information.
- Inconsistent handling of API and database errors.

## 3. Project Objectives

The automation was designed to:

1. Receive incoming leads through a secured HTTP API.
2. Validate and normalize customer information.
3. Identify existing customers using normalized email addresses.
4. Create new customer records when necessary.
5. Save incoming inquiries in PostgreSQL.
6. Prevent duplicate inquiry creation.
7. Detect conflicting submissions.
8. Return structured HTTP responses.
9. Ensure atomic database writes.
10. Handle concurrent submission attempts.

## 4. Technology Stack

- n8n — Workflow orchestration
- PostgreSQL 18 — Relational database
- Docker Compose — Container orchestration
- Cloudflare Tunnel — HTTPS endpoint exposure
- JavaScript — Input validation and normalization
- PL/pgSQL — Atomic database operations
- PowerShell — API and integration testing

## 5. Implemented Features

### Lead Intake API

Receives customer inquiries through an
authenticated POST webhook.

### Input Validation

Validates required fields, supported service
types, US ZIP codes, phone numbers, UUIDs,
and ISO 8601 timestamps.

### Customer Deduplication

Uses normalized email addresses and a
database UNIQUE constraint to avoid duplicate
customer records.

### Submission Idempotency

Uses submission IDs and SHA-256 payload hashes
to distinguish repeated submissions from
conflicting requests.

### Atomic Database Operations

A PostgreSQL function processes customer
creation and inquiry creation within a
single transaction.

### Concurrency Protection

Transaction-scoped advisory locks and database
constraints protect against duplicate processing
of identical submission IDs.

### Structured API Responses

Implemented response codes:

- 201 — Inquiry created
- 200 — Duplicate submission accepted
- 409 — Submission conflict
- 422 — Validation error
- 500 — Internal server error

## 6. Testing Summary

The following scenarios were tested:

- Valid new customer submission
- Existing customer submitting another inquiry
- Missing required fields
- Multiple validation errors
- Optional phone number omitted
- Identical duplicate submission
- Conflicting submission payload
- Database transaction rollback
- Concurrent requests using the same submission ID
- 20-request concurrent load test
- Database error handling

The 20-request load test produced:

- 1 created submission
- 19 duplicate submissions
- 0 reported errors

Database checks confirmed that only one
customer and one inquiry were created.

## 7. Known Limitations

- The native n8n Header Auth mechanism returns
  HTTP 403 for invalid API credentials, while
  the target API contract specifies HTTP 401.
- Deployment and final production readiness
  checks have not yet been completed.
- Additional failure-mode, concurrency, and
  security testing is recommended.

## 8. Project Outcome

The development implementation demonstrates
a functioning lead intake workflow backed by
PostgreSQL, with validation, customer
deduplication, submission idempotency,
transactional persistence, and structured
error responses.

The project is intended as a technical
portfolio demonstration and does not represent
a real client deployment.
