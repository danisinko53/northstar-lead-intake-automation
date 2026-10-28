# Northstar Home Services — Lead Intake Automation

A fictional US home-services client project implemented with n8n, PostgreSQL and Docker. An authenticated API accepts service inquiries, reuses customer records by normalized email, prevents duplicate submissions and routes work to the appropriate team. A separate outbox workflow sends assignment emails.

**Stack:** n8n 2.45.4 · PostgreSQL 18 · Docker Compose · Cloudflare Tunnel/Worker · Gmail OAuth2 · PowerShell

## Repository

- `workflows/` — two sanitized n8n workflow exports
- `migrations/` — 22 ordered SQL migrations
- `deployment/` — Compose template, environment example, Worker source and setup scripts
- `tests/` — repeatable API acceptance checks
- `docs/` — API contract, architecture, test evidence and requirements matrix

## Run and verify

Follow [deployment/README.md](deployment/README.md) for setup, secrets, credentials and Cloudflare routing. Import both workflows with credentials reassigned; never publish live API keys or OAuth credentials.

Run the tested API checks from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-NorthstarAcceptance.ps1 -ApiUrl "https://YOUR_N8N_HOST/webhook/lead-intake"
```

The development system passed all 14 automated acceptance cases (T01–T12, T17–T18). Other brief scenarios were tested separately; see [test report](docs/04-test-report.md).

**Scope:** simulated client/development environment; not a production deployment. A complete fresh-stack Gmail/Cloudflare end-to-end deployment remains unverified. The recorded demonstration is deferred.
