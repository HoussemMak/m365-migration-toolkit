# SONDE de suivi de migration (générique).
# - DRIVE (progression) : LIVE via PnP (bibliothèques du site d'archivage + OneDrive des comptes "OneDrive=yes").
# - DRIVE (erreurs)      : depuis les rapports Migration Manager exportés dans -ReportDir (facultatif).
# - MAIL                 : LIVE via Exchange (boîtes de data/mailboxes.csv).
param(
    [string]$ReportDir = (Join-Path $PSScriptRoot "..\reports"),
    [switch]$NoDrive,
    [switch]$NoMail
)
$ErrorActionPreference = "Continue"
$Cfg = & "$PSScriptRoot\_Config.ps1"
$mbx = Import-Csv (Join-Path $PSScriptRoot "..\data\mailboxes.csv")
$sysLibs = @('Documents','Bibliothèque de styles','Modèles de formulaire','Pièces jointes','Style Library','Form Templates','Site Assets')

Write-Host "================ SONDE MIGRATION - $($Cfg.client.name) ================" -ForegroundColor Cyan
Write-Host ("Heure : " + (Get-Date -Format "yyyy-MM-dd HH:mm"))

if (-not $NoDrive) {
    Write-Host "`n===== DRIVE - progression LIVE (destination) =====" -ForegroundColor Yellow
    try {
        Import-Module PnP.PowerShell -ErrorAction Stop
        Connect-PnPOnline -Url $Cfg.sharepoint.archiveSiteUrl -Interactive -ClientId $Cfg.microsoft365.pnpClientId -ErrorAction Stop
        $tot=0
        Get-PnPList | Where-Object { $_.BaseTemplate -eq 101 -and -not $_.Hidden -and $_.Title -notin $sysLibs } | Sort-Object Title | ForEach-Object {
            "  {0,-44} items = {1}" -f $_.Title, $_.ItemCount; $tot += $_.ItemCount
        }
        Write-Host ("  -- Sous-total site d'archivage : {0} --" -f $tot) -ForegroundColor Green
        Disconnect-PnPOnline
    } catch { Write-Host ("  Lecture site d'archivage impossible : " + $_.Exception.Message) }

    Write-Host "`n  -- OneDrive (comptes OneDrive=yes) --"
    foreach ($u in ($mbx | Where-Object { $_.OneDrive -eq 'yes' })) {
        $od = $Cfg._OneDriveHostUrl + "/personal/" + ($u.EmailAddress -replace '[@.]','_')
        try {
            Connect-PnPOnline -Url $od -Interactive -ClientId $Cfg.microsoft365.pnpClientId -ErrorAction Stop
            $d = Get-PnPList -Identity "Documents" -ErrorAction Stop
            "  OneDrive {0,-26} items = {1}" -f $u.EmailAddress, $d.ItemCount
            Disconnect-PnPOnline
        } catch { "  OneDrive {0,-26} (inaccessible - accorder admin de collection)" -f $u.EmailAddress }
    }

    $errFile = Get-ChildItem -Path $ReportDir -Filter "ProjectError*.csv" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($errFile) {
        Write-Host "`n===== DRIVE - erreurs (rapport MM) =====" -ForegroundColor Yellow
        $err = Import-Csv -LiteralPath $errFile.FullName
        $transient=@('MJOBNOTCOMPLETED'); $benign=@('MEXPORTFILEUNSUPPORTEDMIMETYPE')
        foreach ($g in ($err | Group-Object ResultCode | Sort-Object Count -Descending)) {
            $cat = if ($g.Name -in $transient){"[transitoire]"} elseif ($g.Name -in $benign){"[benin]"} else {"[A TRAITER]"}
            "  {0,5}  {1,-34} {2}" -f $g.Count, $g.Name, $cat
        }
    }
}

if (-not $NoMail) {
    Write-Host "`n===== MAIL - statut LIVE (Exchange) =====" -ForegroundColor Yellow
    try {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
        if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
            Connect-ExchangeOnline -UserPrincipalName $Cfg.microsoft365.adminUpn -ShowBanner:$false | Out-Null
        }
        foreach ($u in $mbx) {
            $s = Get-MigrationUserStatistics -Identity $u.EmailAddress -ErrorAction SilentlyContinue
            if ($s) { "  {0,-28} {1,-12} sync={2}" -f $u.EmailAddress, $s.Status, $s.SyncedItemCount }
        }
    } catch { Write-Host ("  Mail non interrogeable : " + $_.Exception.Message) }
}
Write-Host "`n=======================================================" -ForegroundColor Cyan
