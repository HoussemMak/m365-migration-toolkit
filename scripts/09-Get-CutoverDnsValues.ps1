# Affiche les valeurs DNS EXACTES de cutover pour le client (MX, SPF, DKIM, autodiscover).
# Lit : config. Récupère les CNAME DKIM RÉELS via Exchange (les crée désactivés si besoin).
$ErrorActionPreference = "Stop"
$Cfg = & "$PSScriptRoot\_Config.ps1"
$domain = $Cfg.google.primaryDomain

Import-Module ExchangeOnlineManagement -ErrorAction Stop
if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -UserPrincipalName $Cfg.microsoft365.adminUpn -ShowBanner:$false | Out-Null
}
$dk = Get-DkimSigningConfig -Identity $domain -ErrorAction SilentlyContinue
if (-not $dk) {
    Write-Host "Création de la config DKIM (désactivée) pour obtenir les CNAME..." -ForegroundColor Cyan
    New-DkimSigningConfig -DomainName $domain -Enabled $false -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 8
    $dk = Get-DkimSigningConfig -Identity $domain
}

Write-Host "`n===== VALEURS DNS DE CUTOVER - $domain =====" -ForegroundColor Green
Write-Host ("MX           @                       -> {0}  (priorité 0)" -f $Cfg._MxRecord)
Write-Host  "SPF (TXT)    @                       -> v=spf1 [includes Google existants] include:spf.protection.outlook.com ~all"
Write-Host ("DKIM CNAME   selector1._domainkey    -> {0}" -f $dk.Selector1CNAME)
Write-Host ("DKIM CNAME   selector2._domainkey    -> {0}" -f $dk.Selector2CNAME)
Write-Host  "CNAME        autodiscover            -> autodiscover.outlook.com"
Write-Host ("DKIM activé ? {0}  (l'activer le jour J : Set-DkimSigningConfig -Identity $domain -Enabled `$true)" -f $dk.Enabled)
Write-Host "`nRollback MX (valeurs Google d'origine à conserver AVANT bascule) : à relever dans la zone DNS actuelle." -ForegroundColor DarkGray
