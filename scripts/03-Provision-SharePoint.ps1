# Provisionne le site d'archivage SharePoint + 1 bibliothèque par disque partagé Google.
# Lit : config/client-config.json + data/shared-drives.csv
# Chaque bibliothèque est créée avec un slug propre (URL) puis renommée avec le titre (= nom Google).
param([switch]$WhatIfOnly)
$ErrorActionPreference = "Stop"
$Cfg = & "$PSScriptRoot\_Config.ps1"
$drives = Import-Csv (Join-Path $PSScriptRoot "..\data\shared-drives.csv")

Import-Module PnP.PowerShell -ErrorAction Stop
$cid = $Cfg.microsoft365.pnpClientId

Write-Host "== Connexion à l'admin SharePoint ($($Cfg._SpoAdminUrl)) ==" -ForegroundColor Cyan
Connect-PnPOnline -Url $Cfg._SpoAdminUrl -Interactive -ClientId $cid -ErrorAction Stop

# 1) Créer le site
$site = $Cfg.sharepoint.archiveSiteUrl
$existing = Get-PnPTenantSite -Url $site -ErrorAction SilentlyContinue
if ($existing) { Write-Host "Site déjà existant : $site" -ForegroundColor Yellow }
elseif ($WhatIfOnly) { Write-Host "[WhatIf] Créerait : $site" }
else {
    Write-Host "Création du site : $site" -ForegroundColor Green
    New-PnPSite -Type TeamSiteWithoutMicrosoft365Group -Title $Cfg.sharepoint.archiveSiteTitle -Url $site -Owner $Cfg.sharepoint.owner -ErrorAction Stop | Out-Null
}

# 2) Créer les bibliothèques
Write-Host "== Connexion au site cible ==" -ForegroundColor Cyan
Connect-PnPOnline -Url $site -Interactive -ClientId $cid -ErrorAction Stop
foreach ($d in $drives) {
    $l = Get-PnPList -Identity $d.Title -ErrorAction SilentlyContinue
    if ($l) { Write-Host "  Déjà présente : $($d.Title)" -ForegroundColor Yellow; continue }
    if ($WhatIfOnly) { Write-Host "  [WhatIf] $($d.Title) (URL: $($d.Slug))"; continue }
    Write-Host "  Création : $($d.Title)  (URL: $($d.Slug))" -ForegroundColor Green
    New-PnPList -Title $d.Slug -Template DocumentLibrary -EnableVersioning -ErrorAction Stop | Out-Null
    Set-PnPList -Identity $d.Slug -Title $d.Title -ErrorAction Stop
}
Write-Host "Terminé. Site et bibliothèques prêts." -ForegroundColor Green
Disconnect-PnPOnline
