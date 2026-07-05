# Vérifie les prérequis du poste (modules PowerShell + GAM + config).
$ErrorActionPreference = "Continue"
Write-Host "===== Vérification des prérequis =====" -ForegroundColor Cyan

foreach ($m in "PnP.PowerShell","ExchangeOnlineManagement","Microsoft.Graph.Authentication") {
    $mod = Get-Module -ListAvailable -Name $m | Select-Object -First 1
    if ($mod) { Write-Host ("  OK  {0} {1}" -f $m, $mod.Version) -ForegroundColor Green }
    else { Write-Host ("  MANQUE {0}  ->  Install-Module {0} -Scope CurrentUser" -f $m) -ForegroundColor Red }
}

$Cfg = $null
try { $Cfg = & "$PSScriptRoot\_Config.ps1"; Write-Host ("  OK  config client : {0}" -f $Cfg.client.name) -ForegroundColor Green }
catch { Write-Host ("  CONFIG : {0}" -f $_.Exception.Message) -ForegroundColor Red }

if ($Cfg) {
    $gam = $Cfg.google.gamPath
    if (Test-Path $gam) { Write-Host ("  OK  GAM : {0}" -f $gam) -ForegroundColor Green }
    else { Write-Host ("  GAM introuvable : {0} (installer GAM7)" -f $gam) -ForegroundColor Yellow }
    if (Test-Path $Cfg.microsoft365.serviceAccountKeyPath) { Write-Host "  OK  clé compte de service présente" -ForegroundColor Green }
    else { Write-Host "  Clé compte de service absente (voir METHODOLOGIE étape 3)" -ForegroundColor Yellow }
}
Write-Host "`nNB : Excel et un navigateur (auth interactive PnP/EXO/Graph) sont aussi nécessaires."
