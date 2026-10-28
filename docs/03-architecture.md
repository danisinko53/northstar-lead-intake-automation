# Architecture

```mermaid
flowchart LR
    B[Trusted backend] --> C[Cloudflare Tunnel / Worker]
    C --> A[NHS-001 intake API]
    A --> P[(PostgreSQL)]
    P --> O[(Notification outbox)]
    S[NHS-002 scheduled dispatcher] --> O
    S --> G[Gmail OAuth2]
```

**NHS-001 (16 nodes):** database-backed API-key verification → JavaScript validation → `northstar_save_lead(jsonb)` → HTTP response. PostgreSQL handles customer matching, idempotency, routing and transactional persistence. Validation and processing failure branches record audit events when database access allows it.

**Database:** `customers`, `inquiries`, `service_routing`, `audit_events`, `notification_outbox`, `api_auth_keys`. The restricted `northstar_app` role has application-specific privileges; API-key hashes are checked through a `SECURITY DEFINER` function without granting the app direct access to the key table.

**NHS-002 (6 nodes):** scheduled recovery of stale claims → claim pending outbox item with `FOR UPDATE SKIP LOCKED` → Gmail send → mark sent or schedule retry. Notification delivery is **at least once**: a crash after Gmail accepts a message but before the database is updated can cause a repeat email.

The Docker setup separates n8n, PostgreSQL and Cloudflare Tunnel; it does not publish the database port. Production concerns such as backup restores, monitoring, rate limiting and data-retention policy require separate design.

See [deployment instructions](../deployment/README.md) for environment variables, credentials and Worker routing.
