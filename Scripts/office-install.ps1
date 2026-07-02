# =========================================================================
# Имя файла: office-install-full.ps1
# Назначение: Автоматическая установка и активация Microsoft Office LTSC 2024
# Оптимизация: Только Word, Excel, PowerPoint + Авто-KMS
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Настройка путей
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
$LogFile = Join-Path $LogDir "office2024-install.log"

# Функция для моментальной записи в лог
function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "HH:mm:ss"
    $LogLine = "[$Timestamp] $Message"
    $LogLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $LogLine
}

# Проверка прав Администратора
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "ОШИБКА: Скрипт необходимо запустить от имени Администратора!"
    Start-Sleep -Seconds 5
    Exit
}

# Включение TLS
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 12288
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

Write-Log "========================================================="
Write-Log " ЗАПУСК ПОЛНОЙ УСТАНОВКИ И АКТИВАЦИИ MICROSOFT OFFICE 2024"
Write-Log "========================================================="

# =========================================================================
# ЭТАП 2: ФУНКЦИИ-ПОМОЩНИКИ
# =========================================================================

function Invoke-SafeRetry {
    param([scriptblock]$Script, [int]$Count=3, [int]$DelaySec=5)
    for($i=1; $i -le $Count; $i++){
        try { return & $Script } catch {
            if($i -eq $Count){ throw }
            Start-Sleep -Seconds $DelaySec
        }
    }
}

function Download-SetupFile {
    param([string]$Uri, [string]$OutFile)
    Invoke-SafeRetry -Count 3 -DelaySec 5 -Script {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $OutFile -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } -TimeoutSec 300
        } catch {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $webClient.DownloadFile($Uri, $OutFile)
        }
    }
    if(-not (Test-Path $OutFile) -or (Get-Item $OutFile).Length -lt 100KB){
        if (Test-Path $OutFile) { Remove-Item $OutFile -Force -ErrorAction SilentlyContinue }
        throw "Файл поврежден при скачивании: $OutFile"
    }
}

function Install-Executable {
    param([string]$Path, [string]$Arguments)
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        Write-Log "WARNING: Процесс вернул код: $($process.ExitCode)"
    }
}

# =========================================================================
# ЭТАП 3: СКАЧИВАНИЕ И УСТАНОВКА
# =========================================================================

try {
    $TempDir = "C:\Office2024_Temp"
    if (-not (Test-Path $TempDir)) { New-Item -Path $TempDir -ItemType Directory -Force | Out-Null }

    # 3.1: Патч региональной блокировки
    Write-Log ">>> [1/5] Обход региональных ограничений..."
    $RegPath = "HKCU:\Software\Microsoft\Office\16.0\Common\ExperimentConfigs\Ecs"
    if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
    Set-ItemProperty -Path $RegPath -Name "CountryCode" -Value "std::wstring|US" -Type String

    # 3.2: Скачивание ODT
    Write-Log ">>> [2/5] Скачивание компонентов развертывания Microsoft ODT..."
    $OdtUrl = "https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20026-20112.exe"
    $OdtExe = Join-Path $TempDir "odt_setup.exe"
    Download-SetupFile -Uri $OdtUrl -OutFile $OdtExe

    # 3.3: Распаковка ODT
    Write-Log ">>> [3/5] Распаковка файлов установщика..."
    Install-Executable -Path $OdtExe -Arguments "/extract:`"$TempDir`" /quiet"
    Start-Sleep -Seconds 2

    # 3.4: Генерация XML
    Write-Log ">>> [4/5] Создание конфигурационного файла..."
    $XmlContent = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="PerpetualVL2024">
    <Product ID="ProPlus2024Volume" PIDKEY="FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH">
      <Language ID="ru-ru" />
      <ExcludeApp ID="Outlook" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="OneNote" />
      <ExcludeApp ID="Publisher" />
      <ExcludeApp ID="Teams" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="Bing" />
    </Product>
  </Add>
  <RemoveMSI />
  <Property Name="AUTOACTIVATE" Value="1" />
</Configuration>
"@
    $XmlPath = Join-Path $TempDir "configuration.xml"
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($XmlPath, $XmlContent, $Utf8NoBom)

    # 3.5: Запуск фоновой установки
    Write-Log ">>> [5/5] Запуск установки финальной версии Office 2024 LTSC..."
    Write-Log "Внимание: Идет скачивание файлов напрямую с серверов Microsoft. Подождите..."
    $SetupPath = Join-Path $TempDir "setup.exe"
    
    if (Test-Path $SetupPath) {
        Install-Executable -Path $SetupPath -Arguments "/configure `"$XmlPath`""
        Write-Log ">>> Установка файлов завершена."
    } else {
        throw "Критическая ошибка: setup.exe не найден."
    }

    # =========================================================================
    # АВТОМАТИЧЕСКАЯ НАСТРОЙКА АКТИВАЦИИ (KMS)
    # =========================================================================
    Write-Log ">>> [Активация] Подключение к удаленному серверу лицензирования..."
    
    $OfficePath = "C:\Program Files\Microsoft Office\Office16"
    if (Test-Path $OfficePath) {
        Set-Location -Path $OfficePath
        Write-Log "Привязка KMS-сервера: kms.digiboy.ir..."
        cscript ospp.vbs /sethst:kms.digiboy.ir | Out-Null
        
        Write-Log "Отправка запроса на активацию..."
        cscript ospp.vbs /act | Out-Null
        Write-Log ">>> Запрос на активацию отправлен."
    } else {
        Write-Log "WARNING: Папка программы не найдена, пропуск шага активации."
    }

} catch {
    Write-Log "ERROR: Произошел сбой: $($_.Exception.Message)"
} finally {
    Write-Log ">>> Очистка временного мусора установки..."
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Log "========================================================="
Write-Log " ВСЕ ЭТАПЫ ВЫПОЛНЕНЫ."
Write-Log "========================================================="
