param(
    [string]$ApiUrl = "https://n8n.sinko.win/webhook/lead-intake", [string]$ComposeFile = "", [string]$EnvFile = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent

if (-not $ComposeFile) {
    $ComposeFile = Join-Path $repoRoot "deployment/docker-compose.yml"
}

if (-not (Test-Path -LiteralPath $ComposeFile)) {
    throw "Compose file missing: $ComposeFile"
}

$ComposeFile = (Resolve-Path -LiteralPath $ComposeFile).Path
$composeArgs = @("-f", $ComposeFile)

if (-not $EnvFile) {
    $candidate = Join-Path (Split-Path $ComposeFile -Parent) ".env"
    if (Test-Path -LiteralPath $candidate) {
        $EnvFile = $candidate
    }
}

if ($EnvFile) {
    if (-not (Test-Path -LiteralPath $EnvFile)) {
        throw "Environment file missing: $EnvFile"
    }
    $composeArgs = @("--env-file", (Resolve-Path -LiteralPath $EnvFile).Path) + $composeArgs
}

$results = @()

$secretPath = Join-Path $env:APPDATA "Northstar\api-key-v2.dpapi"

if (-not (Test-Path -LiteralPath $secretPath)) {
    throw "Encrypted Northstar v2 API key not found."
}

$encryptedKey = Get-Content -LiteralPath $secretPath -Raw
$secureKey = ConvertTo-SecureString $encryptedKey.Trim()
$apiKey = [System.Net.NetworkCredential]::new("", $secureKey).Password
Remove-Variable encryptedKey -ErrorAction SilentlyContinue

function Send-Lead {
    param(
        [string]$Json
    )

    try {
        $response = Invoke-WebRequest -UseBasicParsing `
            -Uri $ApiUrl `
            -Method Post `
            -Headers @{ "X-API-Key" = $apiKey } `
            -ContentType "application/json" `
            -Body $Json `
            -TimeoutSec 60

        return @{
            Status = [int]$response.StatusCode
            Body = ($response.Content | ConvertFrom-Json)
        }
    }
    catch {
        if ($null -ne $_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            $body = $null

            if ($_.ErrorDetails.Message) {
                try {
                    $body = $_.ErrorDetails.Message | ConvertFrom-Json
                }
                catch {}
            }

            return @{
                Status = $status
                Body = $body
            }
        }

        throw
    }
}

function Send-RawRequest {
    param(
        [string]$Json,
        [hashtable]$Headers = @{}
    )

    try {
        $response = Invoke-WebRequest -UseBasicParsing `
            -Uri $ApiUrl `
            -Method Post `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $Json `
            -TimeoutSec 60

        return @{
            Status = [int]$response.StatusCode
            Body = $response.Content
        }
    }
    catch {
        if ($null -ne $_.Exception.Response) {
            return @{
                Status = [int]$_.Exception.Response.StatusCode
                Body = $_.ErrorDetails.Message
            }
        }
        throw
    }
}
function Assert-Test {
    param(
        [string]$Id,
        [bool]$Condition,
        [string]$Description
    )

    if ($Condition) {
        Write-Host "PASS $Id - $Description" -ForegroundColor Green
        $script:results += [pscustomobject]@{
            Test = $Id
            Result = "PASS"
        }
    }
    else {
        Write-Host "FAIL $Id - $Description" -ForegroundColor Red
        $script:results += [pscustomobject]@{
            Test = $Id
            Result = "FAIL"
        }
    }
}

try {
    $unique = [guid]::NewGuid().ToString("N")
    $id1 = [guid]::NewGuid().ToString()
    $id2 = [guid]::NewGuid().ToString()

    $payload1 = @{
        submission_id = $id1
        first_name = "Automated"
        last_name = "Test"
        email = "acceptance.$unique@example.com"
        phone = "+12025550111"
        service_type = "plumbing"
        zip_code = "10001"
        message = "Automated acceptance test T01."
        submitted_at = (Get-Date).ToUniversalTime().ToString("o")
    }

    $json1 = $payload1 | ConvertTo-Json -Compress

    Write-Host "`n--- T01: NEW CUSTOMER ---"
    $first = Send-Lead $json1

    Assert-Test "T01" (
        $first.Status -eq 201 -and
        $first.Body.success -eq $true -and
        $null -ne $first.Body.data.customer_id -and
        $null -ne $first.Body.data.inquiry_id
    ) "New customer and inquiry created"

    Write-Host "`n--- T02: EXISTING CUSTOMER ---"

    $payload2 = $payload1.Clone()
    $payload2.submission_id = $id2
    $payload2.message = "Automated acceptance test T02."

    $json2 = $payload2 | ConvertTo-Json -Compress
    $second = Send-Lead $json2

    Assert-Test "T02" (
        $second.Status -eq 201 -and
        $second.Body.data.customer_id -eq $first.Body.data.customer_id -and
        $second.Body.data.inquiry_id -ne $first.Body.data.inquiry_id -and
        $null -ne $second.Body.data.inquiry_id
    ) "Customer reused, new inquiry created"

    Write-Host "`n--- T03: IDENTICAL SUBMISSION ---"

    $duplicate = Send-Lead $json2

    Assert-Test "T03" (
        $duplicate.Status -eq 200 -and
        $duplicate.Body.data.customer_id -eq $second.Body.data.customer_id -and
        $duplicate.Body.data.inquiry_id -eq $second.Body.data.inquiry_id
    ) "Duplicate returned original record"

    Write-Host "`n--- T04: SUBMISSION CONFLICT ---"

    $conflictPayload = $payload2.Clone()
    $conflictPayload.message = "Modified message should be rejected."

    $conflict = Send-Lead ($conflictPayload | ConvertTo-Json -Compress)

    # Replaying the original must still return the original inquiry.
    $afterConflict = Send-Lead $json2

    Assert-Test "T04" (
        $conflict.Status -eq 409 -and
        $conflict.Body.error.code -eq "IDEMPOTENCY_CONFLICT" -and
        $afterConflict.Status -eq 200 -and
        $afterConflict.Body.data.inquiry_id -eq $second.Body.data.inquiry_id -and
        $afterConflict.Body.data.customer_id -eq $second.Body.data.customer_id
    ) "Conflict rejected; original inquiry remains accessible"

    # F03_RESPONSE_SCHEMA_CHECK
function Assert-SuccessSchema($response, $expectedSubmissionId) {
    if ($response.Body.success -ne $true -or $null -ne $response.Body.error) {
        throw "F03: Invalid success/error envelope."
    }

    $data = $response.Body.data
    if ($null -eq $data) { throw "F03: Missing data." }

    foreach ($field in @(
        "submission_id", "inquiry_id", "customer_id",
        "status", "assigned_team", "created_at"
    )) {
        if ($data.PSObject.Properties.Name -notcontains $field) {
            throw "F03: Missing response field: $field"
        }
    }

    foreach ($field in @("submission_id", "inquiry_id", "customer_id")) {
        $uuid = [guid]::Empty
        if ($data.$field -isnot [string] -or
            -not [guid]::TryParse($data.$field, [ref]$uuid)) {
            throw "F03: Invalid UUID: $field"
        }
    }

    $timestamp = [datetimeoffset]::MinValue
    if ($data.created_at -isnot [string] -or
        -not [datetimeoffset]::TryParse(
            $data.created_at, [ref]$timestamp
        )) {
        throw "F03: Invalid created_at timestamp."
    }

    if ($data.submission_id -ne $expectedSubmissionId) {
        throw "F03: Incorrect submission_id."
    }

    if ($data.status -isnot [string] -or
        [string]::IsNullOrWhiteSpace($data.status)) {
        throw "F03: Invalid status."
    }

    if ($null -ne $data.assigned_team -and
        $data.assigned_team -isnot [string]) {
        throw "F03: Invalid assigned_team type."
    }
}

Write-Host "`n--- F03: RESPONSE CONTRACT VERIFICATION ---"

Assert-SuccessSchema $first $payload1.submission_id
Assert-SuccessSchema $second $payload2.submission_id
Assert-SuccessSchema $duplicate $payload2.submission_id
Assert-SuccessSchema $afterConflict $payload2.submission_id

foreach ($field in @(
    "submission_id", "inquiry_id", "customer_id",
    "status", "assigned_team", "created_at"
)) {
    if ($duplicate.Body.data.$field -cne $second.Body.data.$field -or
        $afterConflict.Body.data.$field -cne $second.Body.data.$field) {
        throw "F03: Persisted field changed on replay: $field"
    }
}

if ($first.Body.data.status -ne "new" -or
    $second.Body.data.status -ne "new") {
    throw "F03: Unexpected initial inquiry status."
}

if ($first.Body.data.assigned_team -ne "PLUMBING_TEAM" -or
    $second.Body.data.assigned_team -ne "PLUMBING_TEAM") {
    throw "F03: Incorrect plumbing assignment."
}

if ($conflict.Body.success -ne $false -or
    $null -ne $conflict.Body.data -or
    $conflict.Body.error.code -ne "IDEMPOTENCY_CONFLICT") {
    throw "F03: Incorrect conflict envelope."
}

Write-Host "PASS - F03 response schemas and persisted replay fields."
Write-Host "`n--- T05: MISSING EMAIL ---"

    $missingEmail = $payload1.Clone()
    $missingEmail.submission_id = [guid]::NewGuid().ToString()
    $missingEmail.Remove("email")

    $missingResult = Send-Lead ($missingEmail | ConvertTo-Json -Compress)

    Assert-Test "T05" (
        $missingResult.Status -eq 422 -and
        $missingResult.Body.success -eq $false
    ) "Missing email rejected"

    Write-Host "`n--- T06: INVALID EMAIL ---"

    $invalidEmail = $payload1.Clone()
    $invalidEmail.submission_id = [guid]::NewGuid().ToString()
    $invalidEmail.email = "not-an-email"

    $invalidResult = Send-Lead ($invalidEmail | ConvertTo-Json -Compress)

    Assert-Test "T06" (
        $invalidResult.Status -eq 422 -and
        $invalidResult.Body.success -eq $false
    ) "Invalid email rejected"

    Write-Host "`n--- T07: UNKNOWN SERVICE TYPE ---"

    $unknownService = $payload1.Clone()
    $unknownService.submission_id = [guid]::NewGuid().ToString()
    $unknownService.service_type = "unknown_service"

    $unknownResult = Send-Lead ($unknownService | ConvertTo-Json -Compress)

    Assert-Test "T07" (
        $unknownResult.Status -eq 422 -and
        $unknownResult.Body.success -eq $false
    ) "Unknown service type rejected"
    Write-Host "`n--- T08: MISSING API KEY ---"

    $t08 = Send-RawRequest -Json $json1

    Assert-Test "T08" (
        $t08.Status -eq 401
    ) "Missing API key returns HTTP 401 (actual: $($t08.Status))"

    Write-Host "`n--- T09: INCORRECT API KEY ---"

    $t09 = Send-RawRequest `
        -Json $json1 `
        -Headers @{ "X-API-Key" = "invalid-northstar-test-key" }

    Assert-Test "T09" (
        $t09.Status -eq 401
    ) "Incorrect API key returns HTTP 401 (actual: $($t09.Status))"

    Write-Host "`n--- T10: MALFORMED JSON ---"

    $t10 = Send-RawRequest `
        -Json '{"submission_id":"broken","email":' `
        -Headers @{ "X-API-Key" = $apiKey }

    Assert-Test "T10" (
        $t10.Status -eq 400
    ) "Malformed JSON returns HTTP 400 (actual: $($t10.Status))"

    Write-Host "`n--- T11: EMAIL CASE NORMALIZATION ---"

    $t11Payload = $payload1.Clone()
    $t11Payload.submission_id = [guid]::NewGuid().ToString()
    $t11Payload.email = $payload1.email.ToUpperInvariant()
    $t11Payload.message = "Automated acceptance test T11."

    $t11 = Send-Lead ($t11Payload | ConvertTo-Json -Compress)

    Assert-Test "T11" (
        $t11.Status -eq 201 -and
        $t11.Body.success -eq $true -and
        $t11.Body.data.customer_id -eq $first.Body.data.customer_id -and
        $t11.Body.data.inquiry_id -ne $first.Body.data.inquiry_id
    ) "Different email capitalization reuses customer"

    Write-Host "`n--- T12: SAME CUSTOMER, NEW SUBMISSION ID ---"

    $t12Payload = $payload1.Clone()
    $t12Payload.submission_id = [guid]::NewGuid().ToString()
    $t12Payload.message = "Automated acceptance test T12."

    $t12 = Send-Lead ($t12Payload | ConvertTo-Json -Compress)

    Assert-Test "T12" (
        $t12.Status -eq 201 -and
        $t12.Body.success -eq $true -and
        $t12.Body.data.customer_id -eq $first.Body.data.customer_id -and
        $t12.Body.data.inquiry_id -ne $first.Body.data.inquiry_id -and
        $t12.Body.data.inquiry_id -ne $second.Body.data.inquiry_id
    ) "New submission ID creates another inquiry"
    Write-Host "`n--- T17: UNAUTHORIZED VALID PAYLOAD ---"

    $t17Payload = $payload1.Clone()
    $t17Payload.submission_id = [guid]::NewGuid().ToString()
    $t17Payload.email = "t17.$unique@example.com"
    $t17Payload.message = "Unauthorized valid payload must not create business records."

    $t17 = Send-RawRequest -Json (
        $t17Payload | ConvertTo-Json -Compress
    )

    $t17Sql = @"
SELECT (
    (SELECT COUNT(*) FROM public.customers
     WHERE normalized_email = '$($t17Payload.email)')
    +
    (SELECT COUNT(*) FROM public.inquiries
     WHERE submission_id = '$($t17Payload.submission_id)'::uuid)
)::text;
"@

    $t17Db = $t17Sql |
        docker compose @composeArgs exec -T postgres `
        psql -X -A -t -v ON_ERROR_STOP=1 `
        -U northstar -d northstar_crm

    if ($LASTEXITCODE -ne 0) {
        throw "T17 database verification failed."
    }

    $t17Count = ($t17Db | Out-String).Trim()

    Assert-Test "T17" (
        $t17.Status -eq 401 -and
        $t17Count -eq "0"
    ) "Unauthorized valid payload creates no customer or inquiry"

    Write-Host "`n--- T18: SQL INJECTION-LIKE TEXT ---"

    $t18Payload = $payload1.Clone()
    $t18Payload.submission_id = [guid]::NewGuid().ToString()
    $t18Payload.email = "t18.$unique@example.com"
    $t18Payload.message = "'; DROP TABLE public.customers; --"

    $t18 = Send-Lead (
        $t18Payload | ConvertTo-Json -Compress
    )

    $t18Sql = @"
SELECT CASE
    WHEN EXISTS (
        SELECT 1
        FROM public.inquiries
        WHERE submission_id = '$($t18Payload.submission_id)'::uuid
          AND message = `$`$'; DROP TABLE public.customers; --`$`$
    )
    AND to_regclass('public.customers') IS NOT NULL
    THEN 'PASS'
    ELSE 'FAIL'
END;
"@

    $t18Db = $t18Sql |
        docker compose @composeArgs exec -T postgres `
        psql -X -A -t -v ON_ERROR_STOP=1 `
        -U northstar -d northstar_crm

    if ($LASTEXITCODE -ne 0) {
        throw "T18 database verification failed."
    }

    $t18DbResult = ($t18Db | Out-String).Trim()

    Assert-Test "T18" (
        $t18.Status -eq 201 -and
        $t18.Body.success -eq $true -and
        $t18DbResult -eq "PASS"
    ) "SQL injection-like text stored literally; customers table intact"
    Write-Host "`n--- TEST SUMMARY ---"
    $results | Format-Table -AutoSize

    $failed = @($results | Where-Object Result -eq "FAIL")

    if ($failed.Count -gt 0) {
        throw "$($failed.Count) acceptance test(s) failed."
    }

    Write-Host "PASS - All $($results.Count) executed tests" -ForegroundColor Green
}
finally {
    Remove-Variable apiKey, secureKey -ErrorAction SilentlyContinue
}
