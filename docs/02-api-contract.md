# Lead intake API contract

`POST /webhook/lead-intake` over HTTPS. Intended caller: trusted website backend, not client-side JavaScript. Include `Content-Type: application/json` and `X-API-Key: <secret>`.

## Request

```json
{
  "submission_id": "550e8400-e29b-41d4-a716-446655440000",
  "first_name": "Alex",
  "last_name": "Taylor",
  "email": "alex@example.com",
  "phone": "+12025550148",
  "service_type": "plumbing",
  "zip_code": "10001",
  "message": "A kitchen pipe is leaking.",
  "submitted_at": "2026-10-28T14:30:00Z"
}
```

`phone` is optional. Email is normalized for customer matching; ZIP codes are trimmed and checked as five digits; `submitted_at` must have a valid ISO 8601 timezone. The validator enforces the brief's field-length and value constraints.

## Responses

| HTTP | Meaning | Public error code |
|---|---|---|
| `201` | New inquiry stored | — |
| `200` | Exact replay; existing inquiry returned | — |
| `400` | Malformed JSON (Cloudflare Worker) | `BAD_JSON` |
| `401` | Missing/invalid API key | `UNAUTHORIZED` |
| `409` | Reused submission ID with changed normalized payload | `IDEMPOTENCY_CONFLICT` |
| `422` | Field validation failed | `VALIDATION_ERROR` |
| `503` | Authentication database unavailable | Service unavailable response |
| `500` | Processing failure | `INTERNAL_ERROR` |

Successful responses include `success: true` and `data` containing persisted customer/inquiry identifiers and routing details. Errors use `success: false`, `data: null` and an `error` object; no SQL details or secrets are returned.

**Idempotency:** a matching `submission_id` plus normalized payload returns the original inquiry; conflicting reuse returns `409` without replacing it. An accepted new request writes its inquiry, assignment/audit information and outbox entry transactionally.

**Important:** the `400` rewrite depends on the separately deployed Cloudflare Worker. The `503` branch is configured in the exported workflow; the older controlled outage test observed a generic `500` on a different failure path. See [test evidence](04-test-report.md).
