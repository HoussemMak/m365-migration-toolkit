# Crée les boîtes partagées (Type=Shared dans data/mailboxes.csv).
# Lit : config + data/mailboxes.csv
$ErrorActionPreference = "Stop"
$Cfg = & "$PSScriptRoot\_Config.ps1"
$rows = Import-Csv (Join-Path $PSScriptRoot "..\data\mailboxes.csv") | Where-Object { $_.Type -eq "Shared" }

Import-Module ExchangeOnlineManagement -ErrorAction Stop
if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -UserPrincipalName $Cfg.microsoft365.adminUpn -ShowBanner:$false | Out-Null
}
foreach ($m in $rows) {
    $alias = ($m.EmailAddress -split '@')[0]
    if (Get-Recipient -Identity $m.EmailAddress -ErrorAction SilentlyContinue) {
        Write-Host ("DEJA PRESENT : {0}" -f $m.EmailAddress) -ForegroundColor Yellow
    } else {
        New-Mailbox -Shared -Name $alias -DisplayName $m.DisplayName -PrimarySmtpAddress $m.EmailAddress -ErrorAction Stop | Out-Null
        Write-Host ("CREEE : {0} [SharedMailbox]" -f $m.EmailAddress) -ForegroundColor Green
    }
}
Write-Host "Note : les avertissements 'prepopulate ... 0x8004010F' sont bénins (délai de réplication)." -ForegroundColor DarkGray
