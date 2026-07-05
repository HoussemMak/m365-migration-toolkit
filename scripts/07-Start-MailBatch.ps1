# Crée et démarre un lot de migration mail Gmail -> Exchange Online.
# Lit : config. Le CSV doit contenir une colonne "EmailAddress" (boîtes M365 cibles).
# Option A (recommandée) : NE PAS compléter le lot avant le cutover -> sync incrémentielle ~24h.
param(
    [Parameter(Mandatory=$true)][string]$CsvPath,
    [Parameter(Mandatory=$true)][string]$BatchName,
    [string]$EndpointName = "Google-Migration",
    [switch]$AutoStart
)
$ErrorActionPreference = "Stop"
$Cfg = & "$PSScriptRoot\_Config.ps1"
if (-not (Test-Path $CsvPath)) { throw "CSV introuvable : $CsvPath" }

Import-Module ExchangeOnlineManagement -ErrorAction Stop
if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -UserPrincipalName $Cfg.microsoft365.adminUpn -ShowBanner:$false | Out-Null
}
$tdd = $Cfg.migration.targetDeliveryDomain

if (Get-MigrationBatch -Identity $BatchName -ErrorAction SilentlyContinue) {
    Write-Host "Lot déjà existant : $BatchName" -ForegroundColor Yellow
} else {
    $args = @{
        SourceEndpoint       = $EndpointName
        Name                 = $BatchName
        CSVData              = [System.IO.File]::ReadAllBytes($CsvPath)
        TargetDeliveryDomain = $tdd
    }
    if ($AutoStart) { $args.AutoStart = $true }
    New-MigrationBatch @args -ErrorAction Stop | Out-Null
    Write-Host "Lot '$BatchName' créé (TargetDeliveryDomain=$tdd)." -ForegroundColor Green
}
if ($AutoStart) { try { Start-MigrationBatch -Identity $BatchName -ErrorAction SilentlyContinue } catch {} }

Start-Sleep -Seconds 5
$b = Get-MigrationBatch -Identity $BatchName
Write-Host ("=== {0} | Status={1} | Utilisateurs={2} ===" -f $b.Identity, $b.Status, $b.TotalCount)
Get-MigrationUser -BatchId $BatchName | Format-Table Identity, Status, SyncedItemCount, SkippedItemCount -AutoSize
