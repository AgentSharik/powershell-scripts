# =========================================================================
# Имя файла: clean-and-photo.ps1
# Назначение: Очистка системы и активация классического Photo Viewer
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Настройка путей
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
$LogFile = Join-Path $LogDir "System_Optimization.log"

# Функция для моментальной записи в лог
function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "HH:mm:ss"
    $LogLine = "[$Timestamp] $Message"
    $LogLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $LogLine
}

try {
    # ----------------------------------------------------
    # ЭТАП 1: ГЛУБОКАЯ ОЧИСТКА СИСТЕМЫ ОТ МУСОРА (DEBLOAT)
    # ----------------------------------------------------
    Write-Log ">>> Начало очистки встроенного мусора..."

    $BloatList = @(
        "Yandex.Music",
        "Microsoft.ZuneMusic",
        "office.outlook",
        "windowscommunicationsapps",
        "Microsoft.3DViewer",
        "Microsoft.MixedReality.Portal",
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.BingFinance",
        "Microsoft.BingSports",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.YourPhone",
        "Microsoft.MicrosoftTeams",
        "Microsoft.SkypeApp",
        "Microsoft.54958562F4433"
    )

    foreach ($App in $BloatList) {
        Write-Log "Удаление пакета: $App"
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -match $App } | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match $App } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
    Write-Log ">>> Очистка UWP-приложений завершена."

    # Полное удаление OneDrive
    Write-Log ">>> Удаление OneDrive..."
    Stop-Process -Name 'OneDrive' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") { Start-Process "$env:SystemRoot\System32\OneDriveSetup.exe" -ArgumentList '/uninstall' -Wait }
    if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList '/uninstall' -Wait }

    # ----------------------------------------------------
    # ЭТАП 2: АКТИВАЦИЯ КЛАССИЧЕСКОГО ПРОСМОТРА ФОТО
    # ----------------------------------------------------
    Write-Log ">>> Активация Просмотра фотографий Windows 7..."
    
    $assocPath = "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations"
    if (-not (Test-Path $assocPath)) { New-Item -Path $assocPath -Force | Out-Null }
    @(".jpg",".jpeg",".png",".bmp",".gif",".tif",".tiff",".jfif",".wdp") | ForEach-Object {
        Set-ItemProperty -Path $assocPath -Name $_ -Value "PhotoViewer.FileAssoc.Tiff" -Force
    }

    $daaPath = "C:\Windows\Setup\Scripts\DefaultAppAssociations.xml"
    New-Item -ItemType Directory -Force -Path (Split-Path $daaPath) | Out-Null
    $xmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".jpg"  ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".jpeg" ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".jfif" ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".png"  ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".bmp"  ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".gif"  ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".tif"  ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".tiff" ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".wdp"  ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
</DefaultAssociations>
'@
    [System.IO.File]::WriteAllText($daaPath, $xmlContent, [System.Text.Encoding]::UTF8)

    $dismArgs = @("/Online", "/Import-DefaultAppAssociations:$daaPath")
    $p = Start-Process -FilePath "dism.exe" -ArgumentList $dismArgs -PassThru -Wait -NoNewWindow
    if ($p.ExitCode -ne 0) { throw "DISM завершился с кодом $($p.ExitCode)." }

    Set-ItemProperty -Path "HKLM:\SOFTWARE\RegisteredApplications" -Name "Windows Photo Viewer" -Value "SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities" -Force
    
    Write-Log ">>> Просмотр фотографий успешно настроен по умолчанию!"

} catch {
    Write-Log "WARNING: Ошибка во время оптимизации: $($_.Exception.Message)"
}
