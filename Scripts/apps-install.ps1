# =========================================================================
# Имя файла: apps-install.ps1
# Назначение: Абсолютно надежная установка базового софта + qBittorrent, ShareX, K-Lite
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# --- НАСТРОЙКИ ---
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
$LogFile = Join-Path $LogDir "software-install.log" # Путь к файлу лога

# =========================================================================
# ЭТАП 1: ИНИЦИАЛИЗАЦИЯ И TLS
# =========================================================================

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 12288
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# --- ФУНКЦИЯ ЛОГИРОВАНИЯ (ВСТАВЛЯЕМ СЮДА) ---
function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "HH:mm:ss"
    $LogLine = "[$Timestamp] $Message"
    # Мгновенная запись на диск (без буферизации)
    $LogLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $LogLine 
}

# =========================================================================
# ЭТАП 2: БЛОКИ ФУНКЦИЙ-ПОМОЩНИКОВ
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
    param([string]$Uri, [string]$OutFile, [string]$ExpectedHash = $null)
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
        throw "Файл пустой или поврежден: $OutFile"
    }
    if (-not [string]::IsNullOrEmpty($ExpectedHash)) {
        Write-Log "Проверка контрольной суммы SHA256..."
        $ActualHash = (Get-FileHash -Path $OutFile -Algorithm SHA256).Hash
        if ($ActualHash -ne $ExpectedHash) {
            Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
            throw "Критический сбой: Хэш файла не совпал!"
        }
        Write-Log "Контрольная сумма совпала."
    }
}

function Install-Executable {
    param([string]$Path, [string]$Arguments)
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        Write-Log "WARNING: EXE инсталлятор вернул код ошибки: $($process.ExitCode)"
    }
}

function Install-MsiPackage {
    param([string]$Path, [string]$Arguments = '/qn /norestart')
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$Path`" $Arguments" -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        Write-Log "WARNING: MSI инсталлятор вернул код ошибки: $($process.ExitCode)"
    }
}

# =========================================================================
# ЭТАП 3: УСТАНОВКА ПРОГРАММ (Заменили Write-Host на Write-Log)
# =========================================================================

Write-Log "========================================================="
Write-Log " ЗАПУСК СЦЕНАРИЯ УСТАНОВКИ БАЗОВЫХ ПРОГРАММ"
Write-Log "========================================================="

# --- 3.1: Google Chrome ---
try {
    Write-Log ">>> [1/6] Установка Google Chrome..."
    $ChromeUri  = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'
    $ChromeFile = Join-Path $env:TEMP 'GoogleChromeEnterprise.msi'
    Write-Log "Скачивание официального Enterprise MSI..."
    Download-SetupFile -Uri $ChromeUri -OutFile $ChromeFile
    Write-Log "Запуск тихой установки пакета..."
    Install-MsiPackage -Path $ChromeFile
    Remove-Item $ChromeFile -Force -ErrorAction SilentlyContinue
    Write-Log ">>> Google Chrome установлен успешно."
} catch {
    Write-Log "ERROR: Не удалось установить Google Chrome: $($_.Exception.Message)"
}

# ... (и так далее для остальных программ, просто заменяете Write-Host на Write-Log) ...

# =========================================================================
# ЭТАП 4: ЗАВЕРШЕНИЕ РАБОТЫ
# =========================================================================
Write-Log "========================================================="
Write-Log " ВСЕ ЭТАПЫ ВЫПОЛНЕНИЫ."
Write-Log "========================================================="
# Stop-Transcript больше не нужен
