# Crée (et valide) l'endpoint de migration Gmail dans Exchange Online.
# Lit : config (serviceAccountKeyPath, adminUpn, superAdmin Google).
# Prérequis : compte de service Google + clé JSON + délégation domaine OK (voir METHODOLOGIE étapes 3-4).
param(
    [string]$EndpointName = "Google-Migration",
    [string]$TestEmail
)
$ErrorActionPreference = "Stop"
$Cfg = & "$PSScriptRoot\_Config.ps1"
if (-not $TestEmail) { $TestEmail = $Cfg.google.superAdmin }
$keyPath = $Cfg.microsoft365.serviceAccountKeyPath
if (-not (Test-Path $keyPath)) { throw "Clé JSON introuvable : $keyPath" }

Import-Module ExchangeOnlineManagement -ErrorAction Stop
if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -UserPrincipalName $Cfg.microsoft365.adminUpn -ShowBanner:$false | Out-Null
}

$existing = Get-MigrationEndpoint -Identity $EndpointName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Endpoint déjà existant : $EndpointName (Type=$($existing.EndpointType))" -ForegroundColor Yellow
} else {
    Write-Host "Test de connectivité Google..." -ForegroundColor Cyan
    Test-MigrationServerAvailability -Gmail -ServiceAccountKeyFileData ([System.IO.File]::ReadAllBytes($keyPath)) -EmailAddress $TestEmail
    Write-Host "Création de l'endpoint '$EndpointName'..." -ForegroundColor Green
    New-MigrationEndpoint -Gmail -Name $EndpointName -EmailAddress $TestEmail -ServiceAccountKeyFileData ([System.IO.File]::ReadAllBytes($keyPath)) -ErrorAction Stop | Out-Null
    Write-Host "Endpoint créé et validé." -ForegroundColor Green
}
Write-Host "`nSi 'unauthorized_client / not authorized for any of the scopes' : la délégation domaine manque des scopes." -ForegroundColor DarkGray
Write-Host "Scopes requis (Admin Google > Délégation à l'échelle du domaine) :" -ForegroundColor DarkGray
Write-Host "  https://mail.google.com/,https://www.googleapis.com/auth/calendar,https://www.google.com/m8/feeds/,https://www.googleapis.com/auth/gmail.settings.sharing,https://www.googleapis.com/auth/contacts" -ForegroundColor DarkGray
