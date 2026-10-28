
# Northstar Home Services
## Lead Intake API Contract

**API ID:** NHS-001
**Version:** 1.0
**Environment:** Development / Testing
**Status:** Implemented, production release pending

---

## 1. Endpoint

**Method:** POST

**Development test endpoint:**

https://n8n.sinko.win/webhook-test/lead-intake

**Content-Type:** application/json

The test endpoint is only available while n8n
is listening for a test event.

The production endpoint is not yet published.

## 2. Authentication

Requests must include an API key:

X-API-Key: <YOUR_API_KEY>

Authentication is implemented using n8n
Webhook Header Auth.

Requests with missing or invalid credentials
are rejected before reaching the workflow.

**Known difference:**
The current implementation returns HTTP 403
for invalid credentials. The target contract
specifies HTTP 401.

Never include real API keys in source control,
documentation, screenshots, or client examples.

## 3. Request Body

All requests must contain a JSON object.

### Required Fields

| Field | Type | Validation |
|---|---|---|
| submission_id | string | Valid UUID |
| first_name | string | 1-100 characters after trimming |
| last_name | string | 1-100 characters after trimming |
| email | string | Valid email format, max 254 characters |
| service_type | string | Allowed enum value |
| zip_code | string | Exactly 5 digits |
| message | string | 10-2000 characters after trimming |
| submitted_at | string | Valid ISO 8601 datetime with timezone |

### Optional Fields

| Field | Type | Validation |
|---|---|---|
| phone | string or null | Valid US phone number when provided |

Supported service_type values:

- plumbing
- electrical
- hvac
- general_repair

### Example Request

{
  "submission_id": "2d7a6c91-8b43-4f20-9e75-1c6a8d3b5042",
  "first_name": "Olivia",
  "last_name": "Martinez",
  "email": "olivia.martinez.test@example.com",
  "phone": "+1 (415) 555-0164",
  "service_type": "general_repair",
  "zip_code": "94105",
  "message": "I need help repairing a damaged interior door and replacing its hinges.",
  "submitted_at": "2026-10-28T10:30:00Z"
}

## 4. Input Normalization

Before database processing, the workflow:

- Trims first and last names.
- Trims email addresses.
- Converts normalized_email to lowercase.
- Normalizes valid US phone numbers into
  +1 followed by ten digits.
- Trims the message.
- Converts missing phone values to null.

The original trimmed email is stored separately
from normalized_email.

## 5. Successful Responses

### HTTP 201 - Created

Returned when a new inquiry is successfully saved.

{
  "success": true,
  "data": {
    "inquiry_id": "<generated-uuid>",
    "submission_id": "<submitted-uuid>",
    "customer_id": "<generated-or-existing-uuid>",
    "status": "new",
    "duplicate": false
  },
  "error": null
}

### HTTP 200 - Duplicate

Returned when the same submission_id and
normalized request payload have already
been processed.

{
  "success": true,
  "data": {
    "inquiry_id": "<existing-uuid>",
    "submission_id": "<submitted-uuid>",
    "customer_id": "<existing-uuid>",
    "duplicate": true
  },
  "error": null
}

No additional inquiry is created.

## 6. Error Responses

### HTTP 409 - Submission Conflict

The submission_id already exists, but its
normalized request payload is different.

{
  "success": false,
  "data": null,
  "error": {
    "code": "SUBMISSION_CONFLICT",
    "message": "A submission with this ID already exists with different content.",
    "details": [
      {
        "field": "submission_id",
        "message": "This submission ID has already been used for a different request."
      }
    ]
  }
}

### HTTP 422 - Validation Error

Returned when one or more request fields
fail validation.

{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid fields.",
    "details": [
      {
        "field": "email",
        "message": "Email must be a valid address with a maximum of 254 characters."
      }
    ]
  }
}

The details array may contain multiple errors.

### HTTP 500 - Internal Server Error

Returned when the database operation fails
unexpectedly.

{
  "success": false,
  "data": null,
  "error": {
    "code": "INTERNAL_SERVER_ERROR",
    "message": "An unexpected error occurred while processing your request.",
    "details": []
  }
}

Internal database errors are not included
in the public API response.

## 7. Idempotency Rules

The submission_id is the idempotency key.

The server computes a SHA-256 hash from the
normalized JSON payload.

Processing behavior:

1. New submission_id:
   Save the customer and inquiry.

2. Existing submission_id with matching hash:
   Return HTTP 200 and existing identifiers.

3. Existing submission_id with different hash:
   Return HTTP 409 without modifying the inquiry.

The database enforces uniqueness for:

- customers.normalized_email
- inquiries.submission_id

## 8. Transaction Handling

Customer resolution and inquiry creation are
handled by the PostgreSQL function:

public.northstar_save_lead(jsonb)

The function performs both database writes
atomically within a single transaction.

If a database constraint causes the operation
to fail, changes made by that operation
are rolled back.

Transaction-scoped advisory locks serialize
processing attempts sharing a submission_id.

## 9. Client Integration Guidelines

Clients should:

- Generate a new UUID for each distinct submission.
- Reuse the same UUID when retrying the same request.
- Avoid changing request data when retrying.
- Treat HTTP 200 and 201 as successful responses.
- Display validation errors for HTTP 422.
- Handle HTTP 409 as a submission conflict.
- Treat HTTP 500 as a temporary server failure.
- Keep API credentials out of public frontend code.

For a browser-facing website, use a trusted
backend or server-side endpoint to attach
the API key. Do not embed the API key in
client-side JavaScript.

## 10. Current Limitations

- Invalid API credentials currently return
  HTTP 403 instead of the target HTTP 401.
- The API is currently tested in a development
  environment.
- Production deployment, monitoring, rate
  limiting, and final security review remain
  outstanding.
