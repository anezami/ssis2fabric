$paths = @(
  'C:\Program Files\Microsoft SQL Server\160\DAC\bin\SqlPackage.exe',
  'C:\Program Files\Microsoft SQL Server\170\DAC\bin\SqlPackage.exe',
  'C:\Program Files (x86)\Microsoft SQL Server\160\DAC\bin\SqlPackage.exe',
  'C:\Program Files\Microsoft Visual Studio\2022\*\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\*\SqlPackage.exe'
)
$found = @()
foreach ($p in $paths) {
  $found += Get-ChildItem $p -ErrorAction SilentlyContinue
}
$cmd = Get-Command sqlpackage -ErrorAction SilentlyContinue
if ($cmd) { Write-Host "sqlpackage on PATH: $($cmd.Source)" }
foreach ($f in $found) { Write-Host "Found: $($f.FullName)" }
if (-not $found -and -not $cmd) { Write-Host "NOT FOUND" }
