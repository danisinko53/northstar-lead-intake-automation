param(
    [Parameter(Mandatory)][string]$ContainerName,
    [Parameter(Mandatory)][string]$ExpectedContainerId,
    [string]$Database = 'northstar_crm'
)
$ErrorActionPreference = 'Stop'
if ($Database -notmatch '^[a-z][a-z0-9_]*$') { throw 'Invalid database name.' }
if ($ExpectedContainerId -notmatch '^[0-9a-f]{64}$') { throw 'Full 64-character container ID required.' }
$identity = docker inspect --format '{{.Id}}|{{.State.Running}}|{{.Name}}|{{.HostConfig.NetworkMode}}' $ContainerName
if ($LASTEXITCODE -ne 0 -or $identity -ne "$ExpectedContainerId|true|/$ContainerName|none") { throw 'Target must be the explicitly identified running network-isolated container.' }
$repo = Split-Path $PSScriptRoot -Parent
$files = @(Get-ChildItem (Join-Path $repo 'migrations') -Filter '*.sql' -File | Sort-Object Name)
if ($files.Count -ne 22) { throw "Expected 22 migrations; found $($files.Count)." }
for ($n=1; $n -le 22; $n++) {
    if ($files[$n-1].Name -notmatch ('^{0:D3}_' -f $n)) { throw 'Migration numbering incomplete.' }
}
$before = docker exec $ContainerName psql -X -U northstar -d $Database -t -A -v ON_ERROR_STOP=1 -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('customers','inquiries','api_auth_keys');"
if ($LASTEXITCODE -ne 0 -or ($before | Out-String).Trim() -ne '0') { throw 'Target schema not empty; refusing migration replay.' }
foreach ($file in $files) {
    Write-Host "APPLY $($file.Name)"
    Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | docker exec -i $ContainerName psql -X -q -U northstar -d $Database -v ON_ERROR_STOP=1 -f -
    if ($LASTEXITCODE -ne 0) { throw "Migration failed: $($file.Name). Do NOT rerun on partial database." }
}
$check = docker exec $ContainerName psql -X -U northstar -d $Database -t -A -v ON_ERROR_STOP=1 -c "SELECT (to_regclass('public.api_auth_keys') IS NOT NULL AND to_regprocedure('public.northstar_verify_api_key(text)') IS NOT NULL AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname='northstar_app'))::int;"
if ($LASTEXITCODE -ne 0 -or ($check | Out-String).Trim() -ne '1') { throw 'Migration verification failed.' }
Write-Host 'PASS - 22 migrations applied to isolated container.' -ForegroundColor Green
