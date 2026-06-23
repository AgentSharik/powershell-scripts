# =========================================================================
# Имя файла: install-sys-components.ps1
# Назначение: Установка системных библиотек (Visual C++, DirectX, .NET 3.5, .NET 8.0, OpenAL)
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Логи в Документы Администратора (поддерживает русское имя пользователя)
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
Start-Transcript -Path (Join-Path $LogDir "System_Components_Install.log") -Append

# Вспомогательная функция для безопасного скачивания файлов
function Download-SetupFile {
    param (
        [string]$Uri,
        [string]$OutFile
    )
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 12288
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
    } catch {
        throw "Не удалось скачать файл с $Uri. Ошибка: $($_.Exception.Message)"
    }
    if (-not (Test-Path $OutFile) -or (Get-Item $OutFile).Length -eq 0) {
        throw "Скачанный файл $OutFile пуст или отсутствует."
    }
}

# Вспомогательная функция для скрытого запуска установщиков
function Install-Executable {
    param (
        [string]$Path,
        [string]$Arguments
    )
    try {
        $p = Start-Process -FilePath $Path -ArgumentList $Arguments -PassThru -Wait -NoNewWindow
        if ($p.ExitCode -ne 0) {
            throw "Процесс завершился с ошибкой. Код выхода: $($p.ExitCode)"
        }
    } catch {
        throw "Ошибка при выполнении инсталлятора $($Path): $($_.Exception.Message)"
    }
}

try {
    # ----------------------------------------------------
    # ЭТАП 1: УСТАНОВКА MICROSOFT VISUAL C++ (2015-2022)
    # ----------------------------------------------------
    Write-Host ">>> Шаг 1: Скачивание и тихая установка Visual C++ (x86 и x64)..."
    $Vcx86Uri = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
    $Vcx64Uri = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $Vcx86File = Join-Path $env:TEMP "vc_redist.x86.exe"
    $Vcx64File = Join-Path $env:TEMP "vc_redist.x64.exe"
    
    Write-Host "Скачивание Visual C++ x86..."
    Download-SetupFile -Uri $Vcx86Uri -OutFile $Vcx86File
    Write-Host "Установка Visual C++ x86..."
    Install-Executable -Path $Vcx86File -Arguments "/q /norestart"
    
    Write-Host "Скачивание Visual C++ x64..."
    Download-SetupFile -Uri $Vcx64Uri -OutFile $Vcx64File
    Write-Host "Установка Visual C++ x64..."
    Install-Executable -Path $Vcx64File -Arguments "/q /norestart"
    
    Remove-Item $Vcx86File, $Vcx64File -Force -ErrorAction SilentlyContinue
    Write-Host ">>> Пакеты Microsoft Visual C++ успешно интегрированы."

    # ----------------------------------------------------
    # ЭТАП 2: УСТАНОВКА КОМПОНЕНТОВ DIRECTX
    # ----------------------------------------------------
    Write-Host "`n>>> Шаг 2: Скачивание и тихая установка DirectX End-User Runtimes..."
    $DxUri = "https://download.microsoft.com/download/8/4/a/84a35bf1-dafe-4ae8-82af-ad2ae20b6b14/directx_Jun2010_redist.exe"
    $DxFile = Join-Path $env:TEMP "dx_redist.exe"
    $DxExtractDir = Join-Path $env:TEMP "dx_extract"
    if (-not (Test-Path $DxExtractDir)) { New-Item -ItemType Directory -Path $DxExtractDir | Out-Null }
    
    Download-SetupFile -Uri $DxUri -OutFile $DxFile
    Install-Executable -Path $DxFile -Arguments "/Q /T:`"$DxExtractDir`""
    Install-Executable -Path (Join-Path $DxExtractDir "dxsetup.exe") -Arguments "/silent"
    
    Remove-Item $DxFile -Force -ErrorAction SilentlyContinue
    Remove-Item $DxExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ">>> Все компоненты DirectX успешно установлены."

    # ----------------------------------------------------
    # ЭТАП 3: АКТИВАЦИЯ .NET FRAMEWORK 3.5
    # ----------------------------------------------------
    Write-Host "`n>>> Шаг 3: Включение .NET Framework 3.5 (включает 2.0 и 3.0)..."
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart | Out-Null
        Write-Host ">>> .NET Framework 3.5 успешно активирован."
    } catch {
        Write-Warning "Не удалось активировать .NET Framework 3.5: $($_.Exception.Message)"
    }

    # ----------------------------------------------------
    # ЭТАП 4: УСТАНОВКА СОВРЕМЕННОГО .NET 8.0
    # ----------------------------------------------------
    Write-Host "`n>>> Шаг 4: Скачивание и установка .NET 8.0 Desktop Runtime (x64)..."
    try {
        $Net8Uri = "https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe"
        $Net8File = Join-Path $env:TEMP "dotnet8_runtime.exe"
        
        Download-SetupFile -Uri $Net8Uri -OutFile $Net8File
        Install-Executable -Path $Net8File -Arguments "/q /norestart"
        Remove-Item $Net8File -Force -ErrorAction SilentlyContinue
        Write-Host ">>> .NET 8.0 Desktop Runtime успешно установлен."
    } catch {
        Write-Warning "Не удалось установить .NET 8.0: $($_.Exception.Message)"
    }

    # ----------------------------------------------------
    # ЭТАП 5: УСТАНОВКА ЗВУКОВЫХ БИБЛИОТЕК OPENAL
    # ----------------------------------------------------
    Write-Host "`n>>> Шаг 5: Скачивание и установка OpenAL (3D Audio)..."
    try {
        $OalUri = "https://www.openal.org/downloads/oalinst.zip"
        $OalZip = Join-Path $env:TEMP "oalinst.zip"
        $OalExtractDir = Join-Path $env:TEMP "oal_extract"
        if (-not (Test-Path $OalExtractDir)) { New-Item -ItemType Directory -Path $OalExtractDir | Out-Null }

        # Закачка и распаковка прямой официальной ссылки
        Download-SetupFile -Uri $OalUri -OutFile $OalZip
        Expand-Archive -Path $OalZip -DestinationPath $OalExtractDir -Force
        
        # Инсталлятор лежит прямо в корне архива, запускаем тихо (/S)
        $OalExe = Join-Path $OalExtractDir "oalinst.exe"
        if (Test-Path $OalExe) {
            Install-Executable -Path $OalExe -Arguments "/S"
            Write-Host ">>> Компоненты OpenAL успешно добавлены в систему."
        } else {
            throw "oalinst.exe не найден в корне архива."
        }
        
        # Чистим за собой хвосты
        Remove-Item $OalZip -Force -ErrorAction SilentlyContinue
        Remove-Item $OalExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Не удалось установить OpenAL: $($_.Exception.Message)"
    }

} catch {
    Write-Warning "Критическая ошибка при установке системных компонентов: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}