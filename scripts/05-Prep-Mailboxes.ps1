# Prépare les boîtes cibles avant migration : MRM/rétention en pause + alias en adresses secondaires.
# Lit : config + data/mailboxes.csv (toutes) + data/aliases.csv
# IMPORTANT : RetentionHold évite les faux "éléments manquants" pendant la migration (reco Microsoft).
$ErrorActionPreference = "Continue"
$Cfg = & "$PSScriptRoot\_Config.ps1"
$mbx = Import-Csv (Join-Path $PSScriptRoot "..\data\mailboxes.csv")
$aliasFile = Join-Path $PSScriptRoot "..\data\aliases.csv"

Import-Module ExchangeOnlineManagement -ErrorAction Stop
if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -UserPrincipalName $Cfg.microsoft365.adminUpn -ShowBanner:$false | Out-Null
}

Write-Host "=== Mise en pause MRM / rétention ===" -ForegroundColor Cyan
foreach ($m in $mbx) {
    try { Set-Mailbox -Identity $m.EmailAddress -RetentionHoldEnabled $true -ErrorAction Stop; Write-Host "  MRM en pause : $($m.EmailAddress)" }
    catch { Write-Host ("  ECHEC {0} : {1}" -f $m.EmailAddress, $_.Exception.Message) -ForegroundColor Red }
}

if (Test-Path $aliasFile) {
    Write-Host "`n=== Alias -> adresses secondaires ===" -ForegroundColor Cyan
    foreach ($a in (Import-Csv $aliasFile)) {
        try { Set-Mailbox -Identity $a.MailboxSmtp -EmailAddresses @{add=$a.AliasSmtp} -ErrorAction Stop; Write-Host ("  + {0} -> {1}" -f $a.AliasSmtp, $a.MailboxSmtp) }
        catch { Write-Host ("  ECHEC {0} : {1}" -f $a.AliasSmtp, $_.Exception.Message) -ForegroundColor Red }
    }
}
Write-Host "`nRappel : réactiver le MRM (RetentionHoldEnabled `$false) APRÈS la migration." -ForegroundColor DarkGray
