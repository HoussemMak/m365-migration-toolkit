# Audit Google Workspace via GAM (à lancer dans le terminal du poste : GAM y fonctionne).
# Lit : config. Sort : reports\google\*.csv
# Prérequis : GAM autorisé (gam create project ; gam oauth create) en tant que super admin.
$ErrorActionPreference = "Continue"
$Cfg = & "$PSScriptRoot\_Config.ps1"
$gam = $Cfg.google.gamPath
$dom = $Cfg.google.primaryDomain
$out = Join-Path $PSScriptRoot "..\reports\google"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Gam-Csv($name, [string[]]$arguments) {
    $csv = Join-Path $out "$name.csv"; $log = Join-Path $out "$name.log"
    Write-Host "GAM > $name"
    & $gam redirect csv $csv @arguments *> $log
    if ($LASTEXITCODE -ne 0) { Write-Warning "$name a échoué - voir $log" }
}

& $gam info domain
Gam-Csv "google-users"          @("print","users","allfields")
Gam-Csv "google-groups"         @("print","groups")
Gam-Csv "google-group-members"  @("print","group-members","domain",$dom)
Gam-Csv "google-aliases"        @("print","aliases")
Gam-Csv "google-user-storage"   @("report","users","parameters","accounts:drive_used_quota_in_mb,accounts:gmail_used_quota_in_mb,accounts:total_quota_in_mb")
Gam-Csv "google-shared-drives"  @("print","shareddrives")
Gam-Csv "google-shared-drive-organizers" @("print","shareddriveorganizers","adminaccess")
Write-Host "`nAudit Google terminé -> $out" -ForegroundColor Green
Write-Host "NB : 'print shareddrives' nécessite le compte de service (délégation domaine). Sinon, lister via Admin Google."
