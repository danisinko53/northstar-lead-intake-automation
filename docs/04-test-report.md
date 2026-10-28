
# Northstar Home Services
## Lead Intake API - Test Report

**Project ID:** NHS-001  
**Version:** 1.0  
**Test Date:** October 27-28, 2026  
**Environment:** Local Docker / n8n / PostgreSQL 18  
**Overall Status:** Core functional tests passed; production readiness pending

---

## 1. Test Objectives

The purpose of testing was to verify that the
Lead Intake API can:

- Accept and validate incoming customer inquiries.
- Normalize submitted customer information.
- Create and reuse customer records.
- Store inquiries with correct customer references.
- Prevent duplicate submissions.
- Detect conflicting requests.
- Roll back failed database operations.
- Handle concurrent database requests.
- Return appropriate HTTP responses.
- Handle unexpected database errors.

## 2. Test Environment

| Component | Configuration |
|---|---|
| Workflow engine | n8n |
| Database | PostgreSQL 18 |
| Infrastructure | Docker Compose |
| Public access | Cloudflare Tunnel |
| API testing | PowerShell |
| Database testing | PostgreSQL / n8n |
| API authentication | X-API-Key Header Auth |

Testing was conducted against the development
environment.

The workflow has not yet undergone a complete
production deployment review.

## 3. Functional Test Results

| ID | Test Case | Expected | Observed | Status |
|---|---|---|---|---|
| T-001 | Valid new customer | New customer created | Customer created | PASS |
| T-002 | Valid inquiry | Inquiry linked to customer | Inquiry created | PASS |
| T-003 | Existing customer | Reuse customer_id | Existing ID reused | PASS |
| T-004 | Second inquiry | New inquiry, same customer | Verified | PASS |
| T-005 | Missing email | HTTP 422 | Validation error | PASS |
| T-006 | Invalid email | HTTP 422 | Validation error | PASS |
| T-007 | Invalid service type | HTTP 422 | Validation error | PASS |
| T-008 | Invalid ZIP code | HTTP 422 | Validation error | PASS |
| T-009 | Invalid phone | HTTP 422 | Validation error | PASS |
| T-010 | Invalid timestamp | HTTP 422 | Validation error | PASS |
| T-011 | Multiple invalid fields | Seven errors returned | Seven errors returned | PASS |
| T-012 | Optional phone omitted | Inquiry created | Created | PASS |
| T-013 | Identical submission retry | Duplicate detected | Duplicate detected | PASS |
| T-014 | Conflicting payload | HTTP 409 | Conflict response path executed | PASS |
| T-015 | New transactional request | Created | Created | PASS |
| T-016 | Duplicate transactional request | Duplicate | Duplicate | PASS |
| T-017 | Database error handling | HTTP 500 response | Error response node executed | PASS |

For HTTP response tests where only an n8n
execution screenshot was recorded, the
configured response code and successful
response node execution were verified.

A separate end-to-end client response check
is recommended before production release.

## 4. Database Transaction Tests

### T-018: Atomic Insert

An entirely new customer and inquiry were
created using the database function:

public.northstar_save_lead(jsonb)

Observed result:

result = created

A subsequent JOIN query confirmed that the
customer and inquiry records existed and
were correctly linked.

**Status:** PASS

### T-019: Transaction Rollback

A new customer was submitted with an invalid
service_type.

PostgreSQL rejected the inquiry insert with:

inquiries_service_type_check

A subsequent database query returned:

customer_count = 0
inquiry_count = 0

This verified that the preceding customer
insert had been rolled back.

**Status:** PASS

### T-020: Idempotent Retry

An existing submission was sent again with
identical normalized content.

Observed:

result = duplicate
duplicate = true

The original inquiry and customer IDs were
returned.

**Status:** PASS

### T-021: Submission Conflict

An existing submission_id was reused with
a modified message.

Observed:

result = conflict

No new inquiry was expected to be created.

**Status:** PASS

## 5. Concurrency Tests

### T-022: Two Concurrent Requests

Two independent PowerShell jobs invoked the
same PostgreSQL function with an identical
submission_id.

Observed results:

created = 1
duplicate = 1

A database query confirmed:

customer_count = 1
inquiry_count = 1
distinct_customers = 1

**Status:** PASS

### T-023: Twenty-Request Load Test

Twenty PowerShell background jobs attempted
to submit an identical lead.

Observed summary:

Created: 1
Duplicate: 19
Other: 0

A subsequent database query confirmed:

customer_count = 1
inquiry_count = 1
linked_inquiries = 1

**Status:** PASS

These results demonstrate successful
deduplication in the tested workload.

The test does not guarantee exact simultaneous
execution of all twenty transactions.

## 6. Validation Behavior

The validation layer was tested using an
intentionally malformed request containing
seven invalid fields:

- first_name
- email
- service_type
- zip_code
- message
- submitted_at
- phone

All seven field errors were present in the
validation output.

The invalid request was routed to the
HTTP 422 response node.

The database persistence node was not executed.

**Status:** PASS

## 7. Database Error Handling

A temporary division-by-zero SQL statement
was executed in the Save Lead Transaction node.

The node routed the error through its
dedicated error output.

The Respond - Internal Server Error node
executed with response code 500.

The public JSON response used the generic
error code:

INTERNAL_SERVER_ERROR

The original database query was restored
after testing.

**Status:** PASS

## 8. Authentication Test

An invalid X-API-Key value was submitted.

Observed HTTP status:

403 Forbidden

Target API contract status:

401 Unauthorized

Authentication correctly rejected the request,
but the HTTP status does not match the
target contract.

**Status:** KNOWN DEVIATION

## 9. Test Limitations

The following areas require additional
verification before production deployment:

- Full end-to-end HTTP response regression tests.
- Higher-volume and sustained load testing.
- Database connection failure and recovery.
- Network interruption and timeout handling.
- Retry behavior under infrastructure failures.
- Production rate limiting.
- Authentication and credential rotation.
- Backup restoration testing.
- Production monitoring and alerts.
- Privacy and data retention requirements.

## 10. Test Conclusion

The Northstar Lead Intake API passed the
documented core functional, database,
idempotency, rollback, and concurrency tests.

The 20-request load test returned one created
submission, nineteen duplicates, and zero
reported errors.

The implementation remains a development
portfolio demonstration.

Production readiness requires resolution or
acceptance of known deviations and completion
of the outstanding operational and security
checks.
