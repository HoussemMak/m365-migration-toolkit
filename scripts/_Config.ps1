# Charge la configuration client (config/client-config.json) et calcule les valeurs dérivées.
# Usage dans un script :  $Cfg = & "$PSScriptRoot\_Config.ps1"
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\client-config.json")
)

if (-not (Test-Path $ConfigPath)) {
    throw "Configuration introuvable : $ConfigPath`nCopiez 'config\client-config.example.json' en 'config\client-config.json' et remplissez-le."
}

$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$tenant = $cfg.microsoft365.tenant
$domain = $cfg.google.primaryDomain

# --- Valeurs dérivées (calculées automatiquement, ne pas mettre dans le JSON) ---
$derived = @{
    OnMicrosoftDomain = "$tenant.onmicrosoft.com"
    SpoAdminUrl       = "https://$tenant-admin.sharepoint.com"
    SpoRootUrl        = "https://$tenant.sharepoint.com"
    OneDriveHostUrl   = "https://$tenant-my.sharepoint.com"
    MxRecord          = (($domain -replace '\.', '-') + ".mail.protection.outlook.com")
}
foreach ($k in $derived.Keys) { $cfg | Add-Member -NotePropertyName "_$k" -NotePropertyValue $derived[$k] -Force }

# Validation minimale
$missing = @()
if (-not $tenant) { $missing += "microsoft365.tenant" }
if (-not $domain) { $missing += "google.primaryDomain" }
if (-not $cfg.microsoft365.adminUpn) { $missing += "microsoft365.adminUpn" }
if ($cfg.microsoft365.pnpClientId -eq "00000000-0000-0000-0000-000000000000") {
    Write-Warning "pnpClientId non renseigné : enregistrez d'abord l'app Entra (voir METHODOLOGIE étape 2)."
}
if ($missing.Count -gt 0) { throw "Champs de configuration manquants : $($missing -join ', ')" }

return $cfg
