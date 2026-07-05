# Audit Microsoft 365 (Graph + Exchange + SharePoint via PnP). Lit : config. Sort : reports\m365\*.csv
# Auth interactive (navigateur). Force le tenant CLIENT pour Graph (évite de se connecter au mauvais tenant).
$ErrorActionPreference = "Continue"
$Cfg = & "$PSScriptRoot\_Config.ps1"
$out = Join-Path $PSScriptRoot "..\reports\m365"
New-Item -ItemType Directory -Force -Path $out | Out-Null

# --- Exchange ---
try {
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    Connect-ExchangeOnline -UserPrincipalName $Cfg.microsoft365.adminUpn -ShowBanner:$false | Out-Null
    Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName,UserPrincipalName,PrimarySmtpAddress,RecipientTypeDetails | Export-Csv (Join-Path $out "exo-mailboxes.csv") -NoTypeInformation -Encoding UTF8
    Get-AcceptedDomain | Select-Object Name,DomainName,DomainType,Default | Export-Csv (Join-Path $out "exo-accepted-domains.csv") -NoTypeInformation -Encoding UTF8
    Write-Host "Exchange : OK" -ForegroundColor Green
} catch { Write-Warning "Exchange : $($_.Exception.Message)" }

# --- Graph (tenant client forcé) ---
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Connect-MgGraph -TenantId $Cfg._OnMicrosoftDomain -Scopes "Organization.Read.All","User.Read.All","Directory.Read.All" -NoWelcome -ErrorAction Stop
    $ctx = Get-MgContext
    Write-Host ("Graph connecté au tenant : {0} ({1})" -f $ctx.TenantId, $ctx.Account) -ForegroundColor Green
    (Invoke-MgGraphRequest -Method GET -Uri "/v1.0/subscribedSkus").value |
        ForEach-Object { [pscustomobject]@{ Sku=$_.skuPartNumber; Enabled=$_.prepaidUnits.enabled; Consumed=$_.consumedUnits; Free=($_.prepaidUnits.enabled - $_.consumedUnits) } } |
        Export-Csv (Join-Path $out "graph-skus.csv") -NoTypeInformation -Encoding UTF8
    Write-Host "Graph SKUs : OK" -ForegroundColor Green
} catch { Write-Warning "Graph : $($_.Exception.Message) (pensez à forcer le bon tenant)" }

# --- SharePoint (PnP) ---
try {
    Import-Module PnP.PowerShell -ErrorAction Stop
    Connect-PnPOnline -Url $Cfg._SpoAdminUrl -Interactive -ClientId $Cfg.microsoft365.pnpClientId -ErrorAction Stop
    Get-PnPTenantSite -IncludeOneDriveSites:$true | Select-Object Url,Title,Template,StorageUsageCurrent,SharingCapability |
        Export-Csv (Join-Path $out "spo-sites.csv") -NoTypeInformation -Encoding UTF8
    Disconnect-PnPOnline
    Write-Host "SharePoint : OK" -ForegroundColor Green
} catch { Write-Warning "SharePoint : $($_.Exception.Message)" }

Write-Host "`nAudit M365 terminé -> $out" -ForegroundColor Green
