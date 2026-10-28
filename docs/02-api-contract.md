# Northstar — Lead Intake API Contract

**Workflow:** NHS-001 · **Environment:** development/test · **Review date:** 2026-10-28

## Endpoint and authentication

`POST /webhook/lead-intake` (active workflow); n8n test mode uses `/webhook-test/lead-intake` while listening for an event. HTTPS hostname is deployment-specific.

Required headers:

```http
Content-Type: application/json
X-API-Key: <configured-secret>
```

Only a trusted server/backend should attach the secret. Never place it in browser-side JavaScript or a public repository. n8n **Header Auth currently rejects unauthorized requests with HTTP 403**, whereas the brief specifies **401**.

## Request

| Field | Required | Validation |
|---|---|---|
| `submission_id` | Yes | UUID |
| `first_name`, `last_name` | Yes | Trimmed, 1–100 characters each |
| `email` | Yes | Valid format, at most 254 characters |
| `phone` | No | 7–20 characters by brief; validated/normalized when supplied |
| `service_type` | Yes | `plumbing`, `electrical`, `hvac`, `general_repair` |
| `zip_code` | Yes | Exactly five digits |
| `message` | Yes | Trimmed, 10–2000 characters |
| `submitted_at` | Yes | ISO 8601 date-time with timezone |

```json
{
  "submission_id": "d39c98b4-8fd3-4dd9-a97d-934fd7417bf1",
  "first_name": "Michael",
  "last_name": "Johnson",
  "email": "Michael.Johnson@example.com",
  "phone": "+1-202-555-0148",
  "service_type": "plumbing",
  "zip_code": "10001",
  "message": "My kitchen sink is leaking and I need someone to take a look.",
  "submitted_at": "2026-10-27T14:30:00Z"
}
```

Names, emails and messages are trimmed; email matching uses lowercase `normalized_email`, while the trimmed submitted email is retained. Phone values are normalized when valid. Matching uses **email**, never phone alone.

## Success responses

**HTTP 201 — new inquiry**; **HTTP 200 — identical retry**. Both return the existing/persisted IDs, current stored inquiry status, assigned team and original creation timestamp:

```json
{
  "success": true,
  "data": {
    "submission_id": "d39c98b4-8fd3-4dd9-a97d-934fd7417bf1",
    "inquiry_id": "682394a5-15cc-4bf4-944d-5dc48fa5c891",
    "customer_id": "0c7984be-22ad-4aa2-bb40-cb0c81e93835",
    "status": "new",
    "assigned_team": "PLUMBING_TEAM",
    "created_at": "2026-10-27T14:30:02Z"
  },
  "error": null
}
```

The same `submission_id` with the same normalized payload returns HTTP 200 without creating a new inquiry. If the inquiry's stored status has since changed, duplicate replay returns that **current status**, while IDs and `created_at` stay stable. `assigned_team` can be `null` if manual review is required.

## Errors: target vs observed

| Condition | Brief target | Observed implementation | Notes |
|---|---:|---:|---|
| Missing API key | 401 | **403** | n8n Header Auth rejects before workflow |
| Incorrect API key | 401 | **403** | Same mechanism |
| Malformed JSON syntax | 400 | **422** | n8n body parse failure |
| Field validation | 422 | **422** | JSON `VALIDATION_ERROR`, field details |
| Conflicting submission ID | 409 | **409** | JSON conflict; no business mutation |
| Database outage / processing failure | 500 (503 allowed for temporary outage) | **500** | Generic error, no SQL leak |

The original brief names error codes `UNAUTHORIZED`, `IDEMPOTENCY_CONFLICT`, and `INTERNAL_ERROR`; the implemented conflict/internal response nodes use project-specific codes such as `SUBMISSION_CONFLICT` and `INTERNAL_SERVER_ERROR`. **Exact error-code conformance must be reconciled before strict contract acceptance.**

Observed validation response pattern:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid fields.",
    "details": [{"field": "email", "message": "Email must be a valid address with a maximum of 254 characters."}]
  }
}
```

Observed internal error pattern:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "INTERNAL_SERVER_ERROR",
    "message": "An internal error occurred while processing the request."
  }
}
```

Exact per-path JSON should be validated against the exported workflow before delivery; sample messages are illustrative of tested responses.

## Idempotency and transaction semantics

- The request's `submission_id` is the durable retry key; a SHA-256 hash identifies its **normalized JSON payload**.
- **New ID:** atomically resolve/create customer and insert inquiry → 201.
- **Existing ID, matching hash:** no insert; return existing inquiry → 200.
- **Existing ID, different hash:** do not modify inquiry → 409.
- A uniqueness constraint plus `pg_advisory_xact_lock` protects repeated concurrent submissions.
- The new inquiry initially has status `new` and its coordinator is resolved from `service_routing`.

## Client integration

Generate a UUID per distinct request; reuse the same UUID and unchanged content only for a retry. Handle 200/201 as success, 409 as a conflict, 422 as field validation and 500 as a server failure. Do not assume malformed JSON or missing auth meet the brief's target codes until fixed.

See [Test Report](04-test-report.md) for verification status and [System Architecture](03-architecture.md) for storage and audit behavior.
