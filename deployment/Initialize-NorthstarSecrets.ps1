param(
    [Parameter(Mandatory)][string]$ContainerName,
    [Parameter(Mandatory)][string]$ExpectedContainerId,
    [Parameter(Mandatory)][string]$SecretDirectory,
    [string]$Database = 'northstar_crm'
)
$ErrorActionPreference = 'Stop'
if ($Database -notmatch '^[a-z][a-z0-9_]*$') { throw 'Invalid database name.' }
if ($ExpectedContainerId -notmatch '^[0-9a-f]{64}$') { throw 'Full 64-character container ID required.' }
if (Test-Path -LiteralPath $SecretDirectory) { throw 'Secret directory already exists. Refusing overwrite.' }
$identity = docker inspect --format '{{.Id}}|{{.State.Running}}|{{.Name}}|{{.HostConfig.NetworkMode}}' $ContainerName
if ($LASTEXITCODE -ne 0 -or $identity -ne "$ExpectedContainerId|true|/$ContainerName|none") { throw 'Target must be the explicitly identified running network-isolated container.' }
$preflightSql = @'
SELECT CASE WHEN to_regclass('public.api_auth_keys') IS NULL THEN 'MISSING' WHEN EXISTS(SELECT 1 FROM public.api_auth_keys) THEN 'INITIALIZED' ELSE 'READY' END;
'@
$ready = $preflightSql | docker exec -i $ContainerName psql -X -q -U northstar -d $Database -v ON_ERROR_STOP=1 -t -A -f -
if ($LASTEXITCODE -ne 0 -or ($ready | Out-String).Trim() -ne 'READY') { throw 'Database not ready for first-time initialization.' }
function New-RandomText([int]$length) {
    $bytes = [byte[]]::new($length)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
}
$password = New-RandomText 32
$apiKey = New-RandomText 48
$salt = New-RandomText 24
$created = $false
try {
    New-Item -ItemType Directory -Path $SecretDirectory -ErrorAction Stop | Out-Null
    $created = $true
    foreach ($item in @(@('postgres-app-password.dpapi',$password),@('api-key.dpapi',$apiKey))) {
        $encrypted = ConvertTo-SecureString $item[1] -AsPlainText -Force | ConvertFrom-SecureString
        $dest = Join-Path $SecretDirectory $item[0]
        [System.IO.File]::WriteAllText($dest, $encrypted + "`n", [System.Text.UTF8Encoding]::new($false))
    }
    foreach ($name in @('postgres-app-password.dpapi','api-key.dpapi')) {
        $value = (Get-Content -LiteralPath (Join-Path $SecretDirectory $name) -Raw).Trim() | ConvertTo-SecureString
        if (-not $value) { throw 'DPAPI round-trip failed.' }
    }
    # SQL is passed through stdin. These freshly generated values are URL-safe Base64, not user input.
    $sql = @"
BEGIN;
ALTER ROLE northstar_app PASSWORD '$password';
INSERT INTO public.api_auth_keys (key_id,key_salt,key_hash,is_active)
VALUES ('northstar-initial','$salt',pg_catalog.sha256(pg_catalog.convert_to('$salt' || '$apiKey','UTF8')),TRUE);
COMMIT;
"@
    $sql | docker exec -i $ContainerName psql -X -q -U northstar -d $Database -v ON_ERROR_STOP=1 -f -
    if ($LASTEXITCODE -ne 0) { throw 'Database provisioning failed; encrypted secrets retained for investigation.' }
    $count = docker exec $ContainerName psql -X -U northstar -d $Database -t -A -v ON_ERROR_STOP=1 -c "SELECT COUNT(*) FROM public.api_auth_keys WHERE key_id='northstar-initial' AND is_active;"
    if ($LASTEXITCODE -ne 0 -or ($count | Out-String).Trim() -ne '1') { throw 'Post-commit verification failed; encrypted secrets retained for recovery.' }
    Write-Host 'PASS - Application role password and API key provisioned.' -ForegroundColor Green
    Write-Host 'PASS - Windows DPAPI files saved (current Windows user only).'
    Write-Host "Secret directory: $SecretDirectory"
} catch {
    if ($created) { Write-Warning "Do not delete the encrypted secret files until database state has been reconciled: $SecretDirectory" }
    throw
} finally {
    Remove-Variable password,apiKey,salt,sql -ErrorAction SilentlyContinue
}
