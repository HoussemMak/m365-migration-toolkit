# Génère le tableau de bord Excel (générique) à partir de la config + des résultats.
# Lit : config + data/results-mail.csv + data/results-drive.csv (remplis depuis la sonde/rapports).
# Sort : reports\Tableau-de-bord-<client>.xlsx
$ErrorActionPreference = "Stop"
$Cfg = & "$PSScriptRoot\_Config.ps1"
$mail  = @(Import-Csv (Join-Path $PSScriptRoot "..\data\results-mail.csv"))
$drive = @(Import-Csv (Join-Path $PSScriptRoot "..\data\results-drive.csv"))
$outDir = Join-Path $PSScriptRoot "..\reports"; New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out = Join-Path $outDir ("Tableau-de-bord-{0}.xlsx" -f $Cfg.client.shortCode)
if (Test-Path $out) { Remove-Item $out -Force }

function C([int]$r,[int]$g,[int]$b){ return [int]($r + $g*256 + $b*65536) }
$NAVY=C 31 78 121; $WHITE=C 255 255 255; $LBLUE=C 222 235 247; $BLUE=C 47 84 150
$GREEN_F=C 198 239 206; $GREEN_T=C 0 97 0; $GRAY_F=C 217 217 217; $GRAY_T=C 89 89 89
function Status-Fill($cell,$t){ if($t -eq "Fait"){$cell.Interior.Color=$GREEN_F;$cell.Font.Color=$GREEN_T}elseif($t -eq "À faire"){$cell.Interior.Color=$GRAY_F;$cell.Font.Color=$GRAY_T}; $cell.Font.Bold=$true }

# KPIs calculés depuis les résultats
$mailItems = ($mail | Measure-Object Items -Sum).Sum
$drvItems  = ($drive | Measure-Object Items -Sum).Sum
$volGo = [math]::Round((($mail | Measure-Object GmailGo -Sum).Sum) + (($drive | Measure-Object VolumeGo -Sum).Sum),1)

$xl = New-Object -ComObject Excel.Application; $xl.Visible=$false; $xl.DisplayAlerts=$false
$wb = $xl.Workbooks.Add(); while ($wb.Worksheets.Count -gt 1) { $wb.Worksheets.Item($wb.Worksheets.Count).Delete() }
function Add-Sheet($n){ $w=$wb.Worksheets.Add([System.Reflection.Missing]::Value,$wb.Worksheets.Item($wb.Worksheets.Count)); $w.Name=$n; return $w }
function Make-Table($ws,$r1,$c1,$r2,$c2,$st){ $rng=$ws.Range($ws.Cells.Item($r1,$c1),$ws.Cells.Item($r2,$c2)); $lo=$ws.ListObjects.Add(1,$rng,[System.Reflection.Missing]::Value,1); $lo.TableStyle=$st }
function Write-Sheet($ws,$hr,$headers,$rows,$st,$numCols,$statusCol){
    for($c=0;$c -lt $headers.Count;$c++){ $ws.Cells.Item($hr,$c+1).Value2=[string]$headers[$c] }
    $r=$hr+1
    foreach($row in $rows){ for($c=0;$c -lt $headers.Count;$c++){ if($numCols -contains ($c+1)){$ws.Cells.Item($r,$c+1).Value2=[double]$row.($headers[$c])}else{$ws.Cells.Item($r,$c+1).Value2=[string]$row.($headers[$c])} }
        if($statusCol -gt 0){ Status-Fill $ws.Cells.Item($r,$statusCol) ([string]$row.Status) }; $r++ }
    Make-Table $ws $hr 1 ($r-1) $headers.Count $st; return ($r-1)
}

# 1. Dashboard
$d=$wb.Worksheets.Item(1); $d.Name="Tableau de bord"
$d.Cells.Item(1,1).Value2=("MIGRATION {0} — Google Workspace vers Microsoft 365" -f $Cfg.client.name.ToUpper())
$t=$d.Range("A1:H1"); $t.Merge(); $t.Font.Size=18; $t.Font.Bold=$true; $t.Font.Color=$WHITE; $t.Interior.Color=$NAVY; $t.HorizontalAlignment=-4108; $d.Rows.Item(1).RowHeight=30
$kpis=@(@{l="Données migrées";v="$volGo Go"},@{l="Boîtes mail";v="$($mail.Count)"},@{l="Lecteurs Drive";v="$($drive.Count)"},@{l="Éléments mail";v=("{0:N0}" -f $mailItems)},@{l="Éléments Drive";v=("{0:N0}" -f $drvItems)},@{l="Domaine";v=$Cfg.google.primaryDomain})
$col=1; foreach($k in $kpis){ $d.Cells.Item(3,$col).Value2=$k.l; $d.Cells.Item(3,$col).Font.Size=9; $d.Cells.Item(3,$col).Font.Color=$GRAY_T; $d.Cells.Item(4,$col).Value2=$k.v; $d.Cells.Item(4,$col).Font.Size=14; $d.Cells.Item(4,$col).Font.Bold=$true; $d.Cells.Item(4,$col).Font.Color=$NAVY; $d.Range($d.Cells.Item(3,$col),$d.Cells.Item(4,$col)).Interior.Color=$LBLUE; $d.Columns.Item($col).ColumnWidth=15; $col++ }

# 2. Mail / 3. Drive
$m=Add-Sheet "Mail"; $m.Cells.Item(1,1).Value2="MIGRATION MAIL"; $hm=$m.Range("A1:G1"); $hm.Merge(); $hm.Font.Bold=$true; $hm.Font.Color=$WHITE; $hm.Interior.Color=$NAVY
Write-Sheet $m 3 @("EmailAddress","Person","Type","GmailGo","Items","Status","Note") $mail "TableStyleMedium2" @(4,5) 6 | Out-Null
1..7 | ForEach-Object { $m.Columns.Item($_).AutoFit() }
$dr=Add-Sheet "Drive"; $dr.Cells.Item(1,1).Value2="MIGRATION DRIVE"; $hd=$dr.Range("A1:G1"); $hd.Merge(); $hd.Font.Bold=$true; $hd.Font.Color=$WHITE; $hd.Interior.Color=$NAVY
Write-Sheet $dr 3 @("Source","Type","VolumeGo","Items","Destination","Status","Note") $drive "TableStyleMedium2" @(3,4) 6 | Out-Null
1..7 | ForEach-Object { $dr.Columns.Item($_).AutoFit() }

$wb.Worksheets.Item(1).Activate()
$wb.SaveAs($out,51); $wb.Close(); $xl.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null; [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers()
Write-Host "Dashboard créé : $out" -ForegroundColor Green
