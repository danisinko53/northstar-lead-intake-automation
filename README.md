
# Northstar Home Services
## Automated Lead Intake & CRM Integration

An API-driven lead intake automation built with
n8n, PostgreSQL, Docker, and JavaScript.

**Project status:** Development implementation tested  
**Project type:** Automation portfolio case study  
**Client:** Fictional US home services company

---

## The Challenge

Home service companies receive inquiries from
multiple customers, often through website forms.

Manual lead handling can result in duplicate
customer records, lost inquiries, inconsistent
customer information, and unnecessary
administrative work.

The objective was to create a reliable system
that validates incoming inquiries and stores
them in a structured customer database.

## The Solution

I designed and implemented an automated
lead intake API that:

- Receives requests through an authenticated webhook.
- Validates and normalizes customer information.
- Identifies customers using normalized email addresses.
- Creates customer and inquiry records atomically.
- Prevents duplicate form submissions.
- Detects conflicting submissions.
- Returns structured API responses.
- Handles unexpected database errors.

## Technology Stack

| Technology | Purpose |
|---|---|
| n8n | Workflow automation |
| PostgreSQL 18 | Customer and inquiry database |
| Docker Compose | Local container infrastructure |
| Cloudflare Tunnel | HTTPS webhook access |
| JavaScript | Request validation |
| PL/pgSQL | Transactional database logic |
| PowerShell | API and concurrency testing |

## How It Works

1. A customer submits a service request.
2. n8n authenticates the incoming API request.
3. JavaScript validates and normalizes the data.
4. PostgreSQL checks for an existing submission.
5. The customer record is resolved or created.
6. The inquiry is saved in the same transaction.
7. The API returns the appropriate response.

### API Responses

| HTTP Status | Meaning |
|---|---|
| 201 | New inquiry created |
| 200 | Existing submission returned |
| 409 | Conflicting submission |
| 422 | Invalid request data |
| 500 | Internal processing error |

**Known limitation:** Invalid API credentials
currently return HTTP 403 through n8n Header Auth,
instead of the target HTTP 401 response.

## Database Design

The system uses two main tables:

- `customers` stores customer identity and contact data.
- `inquiries` stores individual service requests.

One customer can have multiple inquiries.

Unique database constraints prevent duplicate
customer emails and submission identifiers.

The PostgreSQL function
`public.northstar_save_lead(jsonb)` performs
customer resolution and inquiry creation in
a single atomic transaction.

## Reliability Testing

The implementation was tested for:

- Valid and invalid submissions.
- Existing and new customers.
- Repeated and conflicting submissions.
- Optional input fields.
- Multiple validation errors.
- Transaction rollback.
- Concurrent submission attempts.
- Unexpected database errors.

### 20-Request Load Test

Twenty concurrent PowerShell jobs submitted
the same lead.

| Result | Count |
|---|---:|
| Created | 1 |
| Duplicate | 19 |
| Other errors | 0 |

A follow-up database query confirmed that
only one customer and one inquiry existed
for the tested submission.

The test demonstrates behavior under the
tested workload; it is not a production
performance benchmark.

## Project Documentation

Detailed technical documentation is available
in the `docs` directory:

- [Project Overview](docs/01-project-overview.md)
- [API Contract](docs/02-api-contract.md)
- [System Architecture](docs/03-architecture.md)
- [Test Report](docs/04-test-report.md)

## Database Migrations

SQL migrations are stored in the
`migrations` directory.

Migration `008_atomic_lead_intake.sql`
implements the transactional lead processing
function.

## Deployment Status

The project currently runs in a Docker-based
development environment.

Production deployment, monitoring, rate limiting,
backup restoration testing, and final security
review remain outstanding.

API keys, database passwords, and other secrets
must not be committed to source control.

## Portfolio Disclaimer

Northstar Home Services is a fictional company
created for this technical portfolio project.

The system demonstrates a realistic automation
solution but does not represent a real client
engagement or production deployment.
