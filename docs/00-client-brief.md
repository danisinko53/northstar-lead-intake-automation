> **Simulated client brief — portfolio exercise.** Northstar Home Services is a fictional company; this is not an actual Upwork contract. The requirements below are reproduced from the original project brief, without implementation-status annotations.

# CLIENT PROJECT BRIEF

## Lead Intake & CRM Automation System

**Client:** Northstar Home Services\
**Project ID:** NHS-AUT-001\
**Contract type:** Fixed-price\
**Budget:** $450 USD (simulated)\
**Deadline:** 7 calendar days\
**Primary stack:** n8n, PostgreSQL\
**API format:** REST/JSON\
**Environment:** Self-hosted, development/staging

---

## 1. Company Background

Northstar Home Services is a growing home maintenance company providing plumbing, electrical, HVAC, and general home repair services.

We operate in three service areas and have a team of eight technicians, two dispatch coordinators, and one office manager.

Our website receives approximately 25–50 customer inquiries per day.

Currently, our staff manually reviews incoming inquiries, checks whether the customer already exists, copies their information into a spreadsheet, and forwards the request to the appropriate coordinator.

This process causes several operational issues:

- Duplicate customer records.
- Missed or delayed inquiries.
- Incorrect service assignments.
- Inconsistent customer communication.
- Limited visibility into the status of individual inquiries.

We need an experienced n8n automation specialist to build the first version of a reliable lead intake system.

## 2. Project Objective

Build an API-driven automation that:

1. Accepts customer inquiries from our website.
2. Authenticates and validates incoming requests.
3. Identifies existing customers.
4. Creates or updates records in PostgreSQL.
5. Prevents duplicate inquiry creation.
6. Routes new inquiries to the appropriate coordinator.
7. Records all relevant processing events.
8. Returns consistent API responses.

The system must handle expected errors without losing valid customer submissions.

**Important:** This is a backend automation project. We are not requesting a CRM frontend or website redesign.

---

## 3. Functional Requirements

### FR-01 — Lead Submission API

Create a publicly reachable HTTPS endpoint:

`POST /webhook/lead-intake`

The endpoint must accept JSON requests and return JSON responses.

All requests must include:

`Content-Type: application/json`

`X-API-Key: <configured-secret>`

The API key must be configured securely and must never be hardcoded into exported workflows or committed to the repository.

Requests with missing or invalid API keys must be rejected.

For this project, assume the endpoint is called by our trusted website backend, not directly from browser JavaScript. The API key must never be exposed in client-side code.

### FR-02 — Input Validation

The API must validate all required fields before inserting business records.

Validation rules:

| Field         | Rules                                                |
| ------------- | ---------------------------------------------------- |
| submission_id | Required, UUID string                                |
| first_name    | Required, 1–100 characters after trimming            |
| last_name     | Required, 1–100 characters after trimming            |
| email         | Required, valid email format, maximum 254 characters |
| phone         | Optional, 7–20 characters, normalized if provided    |
| service_type  | Required, one of the four allowed service types      |
| zip_code      | Required, exactly 5 numeric digits                   |
| message       | Required, 10–2000 characters after trimming          |
| submitted_at  | Required, valid ISO 8601 timestamp with timezone     |

Allowed `service_type` values:

- `plumbing`
- `electrical`
- `hvac`
- `general_repair`

All string inputs must be trimmed where applicable.

Invalid values must be rejected with an appropriate error response.

The system must never create a lead record from a partially validated payload.

### FR-03 — Customer Identification

The system must distinguish between **customers** and **inquiries**.

A customer may submit several inquiries over time.

Customer matching rules:

1. Normalize the incoming email address by trimming whitespace and converting it to lowercase.
2. Search for an existing customer using normalized email.
3. If a matching customer exists, link the inquiry to that customer.
4. If no match exists, create a new customer.
5. Do not create duplicate customer records during concurrent requests.

Email address is the authoritative matching key for this version.

Phone numbers must be stored in normalized form when provided, but must not independently trigger customer merging.

When an existing customer's name or phone differs from the incoming submission, the new inquiry must still be accepted. Do not silently overwrite the existing customer profile. Preserve the submitted information and record the discrepancy for future review.

### FR-04 — Inquiry Idempotency

The system must be safe when the website retries a submission.

Each request contains a unique `submission_id`.

Rules:

- First valid submission: create an inquiry.
- Same `submission_id` and identical normalized payload: return the existing inquiry result.
- Same `submission_id` but conflicting payload: reject with HTTP 409.
- Retrying a submission must never create a second inquiry.
- Concurrent requests with the same `submission_id` must not create duplicate records.

Deduplication must be enforced through durable data constraints, not only by checking whether a record already exists.

### FR-05 — Lead Assignment

Each service category has a designated coordinator.

| Service        | Assigned coordinator code |
| -------------- | ------------------------- |
| plumbing       | PLUMBING_TEAM             |
| electrical     | ELECTRICAL_TEAM           |
| hvac           | HVAC_TEAM                 |
| general_repair | GENERAL_TEAM              |

The assigned coordinator must be stored with the inquiry.

The mapping should be configurable without modifying the incoming API contract.

If an assignment cannot be resolved, the inquiry must remain safely stored and must be flagged for manual review.

### FR-06 — Inquiry Status

Every new inquiry starts with the status:

`new`

The system must support the following statuses at the database level:

- `new`
- `assigned`
- `contacted`
- `qualified`
- `closed`
- `cancelled`

For this initial project, only automatic creation and initial assignment are required.

Do not build the entire lead lifecycle management system.

### FR-07 — Audit Trail

Significant processing events must be recorded.

At minimum:

- Request accepted.
- Validation failure, where safe to log.
- Customer created or matched.
- Inquiry created.
- Duplicate submission detected.
- Assignment completed or failed.
- Unexpected processing failure.

Each event should include:

- Event identifier.
- Event type.
- Related submission or inquiry identifier, when available.
- Timestamp.
- Relevant status or metadata.

Avoid storing API secrets or unnecessary personal information in logs.

### FR-08 — Error Handling

The automation must distinguish between:

- Authentication errors.
- Input validation errors.
- Idempotency conflicts.
- Database errors.
- Unexpected internal failures.

Clients must receive structured responses.

Internal system details, SQL queries, stack traces, and secrets must not be returned in public error messages.

Database errors must not result in partially created or inconsistent customer/inquiry records.

---

## 4. API Contract

### 4.1 Endpoint

**Method:** POST\
**Path:** `/webhook/lead-intake`\
**Content type:** `application/json`\
**Authentication:** `X-API-Key`

### 4.2 Valid Request Example

```
{
  "submission_id": "d39c98b4-8fd3-4dd9-a97d-934fd7417bf1",
  "first_name": "Michael",
  "last_name": "Johnson",
  "email": "michael.johnson@example.com",
  "phone": "+1-202-555-0148",
  "service_type": "plumbing",
  "zip_code": "10001",
  "message": "My kitchen sink is leaking and I need someone to take a look.",
  "submitted_at": "2026-10-27T14:30:00Z"
}
```

### 4.3 Successful Creation — HTTP 201

```
{
  "success": true,
  "data": {
    "submission_id": "d39c98b4-8fd3-4dd9-a97d-934fd7417bf1",
    "inquiry_id": "UUID_GENERATED_BY_SERVER",
    "customer_id": "UUID_GENERATED_BY_SERVER",
    "status": "new",
    "assigned_team": "PLUMBING_TEAM",
    "created_at": "2026-10-27T14:30:02Z"
  },
  "error": null
}
```

`inquiry_id` and `customer_id` must contain actual UUID strings, not the example placeholders above.

### 4.4 Successful Duplicate Replay — HTTP 200

For an identical repeated submission:

```
{
  "success": true,
  "data": {
    "submission_id": "d39c98b4-8fd3-4dd9-a97d-934fd7417bf1",
    "inquiry_id": "EXISTING_INQUIRY_UUID",
    "customer_id": "EXISTING_CUSTOMER_UUID",
    "status": "new",
    "assigned_team": "PLUMBING_TEAM",
    "created_at": "2026-10-27T14:30:02Z"
  },
  "error": null
}
```

The response must contain the originally persisted creation data.

### 4.5 Validation Error — HTTP 422

```
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid fields.",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format."
      }
    ]
  }
}
```

### 4.6 Authentication Error — HTTP 401

```
{
  "success": false,
  "data": null,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or missing authentication credentials."
  }
}
```

### 4.7 Idempotency Conflict — HTTP 409

```
{
  "success": false,
  "data": null,
  "error": {
    "code": "IDEMPOTENCY_CONFLICT",
    "message": "This submission ID has already been used with different data."
  }
}
```

### 4.8 Internal Error — HTTP 500

```
{
  "success": false,
  "data": null,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "The request could not be processed."
  }
}
```

### 4.9 Additional Contract Rules

- Invalid JSON syntax must return HTTP 400.
- Missing or invalid authentication must return HTTP 401.
- Field validation failures must return HTTP 422.
- Idempotency conflicts must return HTTP 409.
- Unexpected server failures must return HTTP 500.
- Temporary service unavailability may return HTTP 503.
- Every completed request must produce a valid HTTP status and JSON body.
- Response IDs must be stable between repeated submissions.
- The API must not leak internal infrastructure details.

---

## 5. PostgreSQL Data Requirements

You are responsible for designing and implementing the database schema.

A database management UI is not required.

### 5.1 Required Data Entities

**Customers**

Must support:

- Stable UUID identifier.
- First name.
- Last name.
- Original and normalized email.
- Optional phone.
- Created and updated timestamps.

**Inquiries**

Must support:

- Stable UUID identifier.
- Original submission identifier.
- Reference to the customer.
- Submitted name and contact information.
- Service type.
- ZIP code.
- Customer message.
- Assigned team.
- Inquiry status.
- Original submission timestamp.
- Record creation timestamp.
- Durable payload identity for idempotency comparison.

**Audit Events**

Must support:

- Unique event identifier.
- Event type.
- Related submission or inquiry, when available.
- Event timestamp.
- Structured metadata.

**Routing Configuration**

Must support service-to-team mapping.

You may create additional tables where appropriate.

### 5.2 Data Integrity Requirements

- Primary keys must enforce uniqueness.
- Foreign keys must preserve valid customer/inquiry relationships.
- The same normalized email must not produce multiple customer records.
- The same submission ID must not produce multiple inquiries.
- Required business fields must not accept NULL.
- Timestamps must be stored consistently with timezone awareness.
- Database-level constraints must complement application-level validation.
- Related writes must remain consistent when failures occur.
- Indexes should support customer lookup and submission lookup efficiently.

### 5.3 Design Decisions to Document

Explain the reasoning behind your choices for:

1. Customer uniqueness.
2. Idempotency enforcement.
3. Transaction boundaries.
4. Payload comparison.
5. Customer information discrepancies.
6. Audit-event retention.
7. Indexing strategy.
8. Behavior under concurrent requests.

Do not add complexity without explaining its operational value.

---

## 6. Acceptance Test Suite

The following tests will be used to evaluate your implementation.

| ID  | Scenario                                        | Expected result                                |
| --- | ----------------------------------------------- | ---------------------------------------------- |
| T01 | Valid new customer and inquiry                  | HTTP 201; one customer and one inquiry created |
| T02 | Existing customer submits a new inquiry         | HTTP 201; existing customer reused             |
| T03 | Identical submission repeated                   | HTTP 200; no new inquiry                       |
| T04 | Same ID with modified message                   | HTTP 409; original record unchanged            |
| T05 | Missing email                                   | HTTP 422; no customer or inquiry created       |
| T06 | Invalid email                                   | HTTP 422                                       |
| T07 | Unknown service type                            | HTTP 422                                       |
| T08 | Missing API key                                 | HTTP 401                                       |
| T09 | Incorrect API key                               | HTTP 401                                       |
| T10 | Malformed JSON                                  | HTTP 400                                       |
| T11 | Same email using different capitalization       | Same customer matched                          |
| T12 | Same customer, different submission ID          | New inquiry created                            |
| T13 | Database temporarily unavailable                | Safe failure; no inconsistent state            |
| T14 | Concurrent identical requests                   | Exactly one inquiry created                    |
| T15 | Routing rule applied                            | Correct coordinator stored                     |
| T16 | Existing customer has conflicting phone number  | Inquiry accepted; discrepancy preserved        |
| T17 | Unauthorized request with valid payload         | No business record created                     |
| T18 | Input contains SQL injection-like text          | Treated as data, not executable SQL            |
| T19 | Missing routing configuration                   | Inquiry preserved and flagged                  |
| T20 | Query audit history for a successful submission | Relevant processing events are available       |

All tests must have reproducible input data and expected results.

At minimum, the developer must automate T01–T12 and T17–T18. Other tests may initially use documented manual procedures.

---

## 7. Sprint 1 — API & Persistence Foundation

**Target effort:** 5–7 focused hours

### Sprint Goal

Deliver a working lead intake API that authenticates requests, validates data, persists customers and inquiries, and prevents duplicates.

No email notifications or advanced team assignment automation are required in Sprint 1.

### Sprint 1 Scope

**Task S1-01 — Database design**

Create the PostgreSQL schema required for customer and inquiry persistence.

Deliverables:

- SQL migration files.
- Primary and foreign keys.
- Unique constraints.
- Appropriate indexes.
- Short schema documentation.

**Task S1-02 — Webhook endpoint**

Create and configure the n8n webhook.

Deliverables:

- Working POST endpoint.
- JSON request parsing.
- API key validation.
- Controlled HTTP responses.

**Task S1-03 — Payload validation**

Implement the defined input validation rules.

Deliverables:

- Required-field checks.
- Format validation.
- Normalization.
- Consistent error responses.

**Task S1-04 — Customer persistence**

Implement customer lookup and creation.

Deliverables:

- Existing customer detection.
- New customer creation.
- Correct inquiry-to-customer relationship.
- Safe behavior under concurrent requests.

**Task S1-05 — Inquiry idempotency**

Implement duplicate submission detection.

Deliverables:

- First-submission handling.
- Identical retry handling.
- Conflicting retry handling.
- Database-enforced uniqueness.

**Task S1-06 — API testing**

Create a reproducible test suite.

Mandatory Sprint 1 tests:

- T01 — New customer.
- T02 — Existing customer.
- T03 — Identical retry.
- T04 — Conflicting retry.
- T05 — Missing email.
- T06 — Invalid email.
- T07 — Unknown service type.
- T08 — Missing API key.
- T09 — Incorrect API key.
- T10 — Malformed JSON.
- T11 — Case-insensitive email matching.
- T12 — New inquiry for existing customer.

### Sprint 1 Definition of Done

Sprint 1 will be accepted when:

- The endpoint is reachable and authenticated.
- All required input validations function correctly.
- Customer and inquiry records are persisted correctly.
- Duplicate submission handling is reliable.
- All 12 mandatory Sprint 1 tests pass.
- SQL migration files are included.
- The project can be reproduced from the documentation.
- No credentials or secrets appear in the exported workflow.
- The solution is demonstrated using actual API requests.

---

## 8. Later Delivery Milestones

### Sprint 2 — Routing & Audit Trail

Estimated effort: 2–4 hours.

Implement:

- Configurable service-based routing.
- Audit-event persistence.
- Unresolved routing behavior.
- Structured internal error recording.
- Tests T15, T16 and T20.

### Sprint 3 — Reliability & Production-Style Hardening

Estimated effort: 3–4 hours.

Implement:

- Failure handling and retry policies.
- Database failure tests.
- Concurrent request tests.
- Security testing.
- Operational documentation.
- Tests T13, T14, T17, T18 and T19.

For this milestone, introduce a reliable notification mechanism for assignment events, with at least one working destination. Customer-facing confirmation emails remain optional for the MVP and must not be included in the initial intake transaction.

---

## 9. Final Handover Requirements

Provide:

1. Exported n8n workflow JSON files.
2. PostgreSQL migration scripts.
3. Environment/configuration setup documentation.
4. API specification and request examples.
5. Automated test collection or executable test scripts.
6. Acceptance test report.
7. Architecture diagram.
8. Error handling and recovery documentation.
9. A short recorded demonstration.

The recorded demonstration must show:

- Successful new customer submission.
- Existing customer identification.
- Duplicate submission handling.
- Validation failure.
- Database records created or reused.
- Assignment and audit records.
- At least one controlled failure scenario.

---

## 10. Evaluation Criteria

| Category                       | Weight |
| ------------------------------ | ------ |
| Functional correctness         | 30%    |
| Reliability and error handling | 25%    |
| Security and data integrity    | 15%    |
| Workflow and database design   | 15%    |
| Documentation and handover     | 15%    |

We prefer a clear, maintainable system over an unnecessarily complex workflow.

The final implementation must be understandable and operable by another technical contractor.

**End of client brief.**
