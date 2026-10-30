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
| `413` | Body larger than 32 KiB (Cloudflare Worker) | `PAYLOAD_TOO_LARGE` |
| `401` | Missing/invalid API key | `UNAUTHORIZED` |
| `409` | Reused submission ID with changed normalized payload | `IDEMPOTENCY_CONFLICT` |
| `422` | Field validation failed | `VALIDATION_ERROR` |
| `503` | Authentication database unavailable | Service unavailable response |
| `500` | Processing failure | `INTERNAL_ERROR` |

Successful responses include `success: true` and `data` containing persisted customer/inquiry identifiers and routing details. Errors use `success: false`, `data: null` and an `error` object; no SQL details or secrets are returned.

**Idempotency:** a matching `submission_id` plus normalized payload returns the original inquiry; conflicting reuse returns `409` without replacing it. An accepted new request writes its inquiry, assignment/audit information and outbox entry transactionally.

**Important:** the `400` rewrite depends on the separately deployed Cloudflare Worker. The `503` branch is configured in the exported workflow; the older controlled outage test observed a generic `500` on a different failure path. See [test evidence](04-test-report.md).

## Edge protection

The separately deployed Cloudflare Worker rejects request bodies larger than 32 KiB with HTTP `413` and `PAYLOAD_TOO_LARGE`. The limit is checked using the declared content length and the bytes read from the request body.

An active Cloudflare rate limiting rule targets the exact URI path `/webhook/lead-intake`, with a configured threshold of 100 requests per 10 seconds per IP and a 10-second block action. Its threshold-crossing behavior has not been independently load-tested.

Authentication behavior is verified at the public API boundary. The underlying n8n endpoint previously exhibited HTTP `403` on authentication failure; callers must use the documented public endpoint. Do not treat direct-origin behavior as independently verified HTTP `401`.
