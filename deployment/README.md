# Northstar — deployment, configuration and recovery

**Fictional portfolio exercise, development/staging handover.** This repository is not evidence of production readiness. Never commit a `.env`, plaintext API key, DB password, tunnel token or OAuth token.

## Architecture

`docker-compose.yml`: PostgreSQL 18 (internal only), n8n 2.45.4 (internal), cloudflared (tunnel). Cloudflare Worker source: `cloudflare/northstar-api-error-handler.js`, normalizing the known n8n malformed JSON parser error to HTTP 400 and rejecting request bodies larger than 32 KiB with HTTP 413. `workflows/` contains credential-free NHS-001 (intake) and NHS-002 (outbox/Gmail). `migrations/001`–`022` build the PostgreSQL schema. **The portable n8n named volume differs from the originally tested host's bind mount.**

## Prerequisites

Docker + Compose, a tunnel and DNS name with working HTTPS routing, a Cloudflare Worker route, PostgreSQL administration, working Google OAuth Gmail configuration, trusted backend for holding the `X-API-Key`, and Windows PowerShell for the optional *isolated-test-only* provisioning helpers.

## Deployment outline

1. Copy `deployment/.env.example` to `deployment/.env`, set nonplaceholder values. Never commit this file. Keep `POSTGRES_DB=northstar_crm` for the documented app-role/bootstrap path. Use a *fresh* Postgres deployment and a unique `N8N_ENCRYPTION_KEY`. The workflow cannot run with dummy credentials.
2. From repository root validate with `docker compose --env-file deployment/.env -f deployment/docker-compose.yml config --quiet`, then run `docker compose --env-file deployment/.env -f deployment/docker-compose.yml up -d`. A tunnel token and correct hostname mapping are required; Compose validation alone does not establish reachable ingress.
3. Apply numbered SQL migrations **once, in order** to a new DB with administrator privileges. Migration 020 creates restricted role `northstar_app` **without a password** and grants CONNECT to `current_database()`; 022 creates `api_auth_keys` and `northstar_verify_api_key(text)`. Roles are PostgreSQL-cluster-wide, not isolated per database. **Do not replay migrations on an existing application DB.**
4. On the actual deployment, set the restricted role password interactively as admin using `psql` and `\password northstar_app` (password prompt is not echoed). Supply it separately to the n8n PostgreSQL credential (host `postgres`, port 5432, database `northstar_crm`, user `northstar_app`). A DB password is not part of `.env.example` since it is not passed to the app nodes by Compose.
5. Generate a high-entropy API key and per-key salt off-repository, and insert a salt/hash row into `public.api_auth_keys` as DB admin: `key_hash = sha256(convert_to(key_salt || api_key, 'UTF8'))`. The plaintext API key belongs **only** in the trusted backend and acceptance test runner; n8n checks it through the DB function. No API key is provisioned by migrations. For Windows isolated provisioning, see the scripts below; **do not run these scripts against the live Northstar container**.
6. Import both sanitized JSON files into n8n; reattach a restricted PostgreSQL credential to every PostgreSQL node of both workflows. In NHS-002 configure Gmail OAuth and an authorized internal recipient; check the schedule, retry and stale-claim behaviors. Both imports are intentionally inactive. Keep NHS-002 off until mail delivery is approved; publish NHS-001 after credential binding.
7. Set up Cloudflare Tunnel ingress to the n8n service, and deploy the Worker source with `ORIGIN_HOST` configured. Configure the route for `/webhook/lead-intake` and `/webhook-test/lead-intake`. **Avoid a Worker fetch loop**: check whether `fetch(request)` on the routed hostname reaches the origin as intended. The workers.dev hostname rewrites to `ORIGIN_HOST`. Verify HTTP 400 `BAD_JSON` for malformed JSON, HTTP 413 `PAYLOAD_TOO_LARGE` for oversized bodies, and HTTP 422 `VALIDATION_ERROR` for valid JSON with invalid fields. Configure a route-specific Cloudflare rate limiting rule for the deployed API; the development endpoint uses 100 requests per 10 seconds per IP with a 10-second block. Threshold-crossing behavior remains untested.
8. Run `tests/Run-NorthstarAcceptance.ps1 -ApiUrl https://YOUR-HOST/webhook/lead-intake` in PowerShell from the repository root after configuring its expected secure API key location. This test creates development records; never run against real customer data. Verify 14/14 PASS. Independently check database outage and Gmail recovery using a disposable test environment.

## Isolated Windows helper scripts

The bundled helpers are restricted to an explicitly identified **Docker container with `--network none`** and check its full 64-digit Docker ID to reduce the chance of changing the wrong PostgreSQL instance. They require the container to run PostgreSQL 18 and an empty `northstar_crm` database with admin role `northstar`. They are **not deployment automation for the running Northstar host**.

From repository root in PowerShell, after creating a throwaway PostgreSQL container:

```powershell
$name = 'northstar-secrets-isolation-test'
$id = (docker inspect --format '{{.Id}}' $name).Trim()
.\deployment\Apply-NorthstarMigrations.ps1 -ContainerName $name -ExpectedContainerId $id
$secretDir = Join-Path $env:TEMP ('northstar-secrets-' + [guid]::NewGuid().ToString('N'))
.\deployment\Initialize-NorthstarSecrets.ps1 -ContainerName $name -ExpectedContainerId $id -SecretDirectory $secretDir
```

These commands **modify the throwaway container's PostgreSQL cluster**. The second creates encrypted `.dpapi` files tied to the current Windows user. Keep those files securely for recovery: an uncertain database commit must never trigger automatic deletion of the only saved secrets. Test setup scripts are not validated merely because their syntax parses; verify functionality in the disposable container before relying on them. After testing, remove the disposable container (`docker rm -f -v northstar-secrets-isolation-test`) and securely handle its temporary secret directory.

## Backup and failure recovery

Postgres stores business data in `northstar_pgdata`; n8n stores configurations in `n8n_data`. Back up both volumes and separately back up the n8n encryption key and connector credentials according to your environment's secret management policy. Backups without a restore test are not verified recovery.

For database authentication failures, intake should return generic HTTP 503 before lead persistence; application save failures should return safe HTTP 500 and rollback business writes. Replays must reuse the same `submission_id` and identical normalized payload. NHS-002 retries failed sends and recovers stale outbox claims. Gmail delivery is at least once: a crash after provider acceptance but before marking sent can duplicate a notification.

## Security and known limits

No public Postgres port in the template. Limit admin role usage to provisioning/migrations, rotate keys, restrict webhook callers, add independent monitoring, backup-restore testing, broader abuse protection, data retention/deletion policy, and perform a proper production security review before real-world use.

**Verification status (2026-10-30):** all 22 migrations applied to an isolated new database and tested again after the `current_database()` portability change; two sanitized n8n exports imported to isolated n8n and kept inactive; acceptance suite 14/14 PASS on the existing development endpoint. A complete newly deployed n8n+Postgres+Gmail+Cloudflare configuration, a tested restore, and recorded demo have **not** been demonstrated. Demo deferred by user request.
