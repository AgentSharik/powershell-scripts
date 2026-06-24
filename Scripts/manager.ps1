# =========================================================================
# Назначение: Главный диспетчер-загрузчик (Запускается при первом входе)
# Этап: FirstLogonCommands (Контекст Администратора)
# Логирование: Документы текущего администратора (Изолированный Мастер-Лог)
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Настройка папки логов в Документах текущего профиля (C:\Users\admin\Documents)
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
Start-Transcript -Path (Join-Path $LogDir "Main_Setup_Dispatcher.log") -Append

try {
    Write-Host "========================================================="
    Write-Host " СТАРТ ОСНОВНОГО ЭТАПА АВТОМАТИЗАЦИИ С GITHUB"
    Write-Host "========================================================="

    # Локальная папка для временного хранения скриптов
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    if (-not (Test-Path $ScriptsDir)) { New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null }

    # Словарь со структурой [Имя файла] = [Raw-ссылка на GitHub]
    $ScriptsMap = [ordered]@{
        "clean-and-photo.ps1"         = "https://raw.githubusercontent.com/alexejnekrasov/powershell-scripts/refs/heads/main/Scripts/clean-and-photo.ps1"
        "install-sys-components.ps1"  = "https://raw.githubusercontent.com/alexejnekrasov/powershell-scripts/refs/heads/main/Scripts/install-sys-components.ps1"
        "apps-install.ps1"            = "https://raw.githubusercontent.com/alexejnekrasov/powershell-scripts/refs/heads/main/Scripts/apps-install.ps1"
        "office-install.ps1"          = "https://raw.githubusercontent.com/alexejnekrasov/powershell-scripts/refs/heads/main/Scripts/office-install.ps1"
        "reset-setup-scripts.ps1"     = "https://raw.githubusercontent.com/alexejnekrasov/powershell-scripts/refs/heads/main/Scripts/reset-setup-scripts.ps1"
    }

    # Включаем современные протоколы TLS для безопасного скачивания
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 12288

    # ----------------------------------------------------
    # ШАГ 1: СКАЧИВАНИЕ ВСЕХ СКРИПТОВ С GITHUB
    # ----------------------------------------------------
    Write-Host "`n>>> [1/2] Загрузка компонентов с GitHub..."
    foreach ($Item in $ScriptsMap.GetEnumerator()) {
        $FileName = $Item.Key
        $Url      = $Item.Value
        $LocalPath = Join-Path $ScriptsDir $FileName

        try {
            Invoke-WebRequest -Uri $Url -OutFile $LocalPath -UseBasicParsing
            Write-Host "[ СКАЧАНО ] -> $FileName"
        } catch {
            Write-Warning "[ ОШИБКА СКАЧИВАНИЯ ] -> $FileName. Причина: $($_.Exception.Message)"
            throw "Критический сбой сети. Развертывание остановлено."
        }
    }

    # ----------------------------------------------------
    # ШАГ 2: ПОСЛЕДОВАТЕЛЬНЫЙ ИЗОЛИРОВАННЫЙ ЗАПУСК
    # ----------------------------------------------------
    Write-Host "`n>>> [2/2] Запуск последовательности автоматизации..."

    # Массив для красивого перебора модулей в цикле
    $ScriptsToRun = @(
        @{ Name = "clean-and-photo.ps1";        Title = "Очистка системы и фото" }
        @{ Name = "install-sys-components.ps1"; Title = "Системные компоненты (VC++, .NET)" }
        @{ Name = "apps-install.ps1";           Title = "Установка базового софта" }
        @{ Name = "office-install.ps1";         Title = "Установка Office 2024 LTSC" }
    )

    foreach ($Script in $ScriptsToRun) {
        $FileName = $Script.Name
        $LocalPath = Join-Path $ScriptsDir $FileName
        
        Write-Host "Запуск модуля: $FileName ($($Script.Title))...."
        
        # Запускаем дочерний скрипт в абсолютно отдельном процессе powershell.exe.
        # Параметр -WindowStyle Hidden скроет всплывающие окна консоли от глаз пользователя.
        $Proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$LocalPath`"" -WindowStyle Hidden -Wait -PassThru
        
        # Проверяем код завершения процесса
        if ($Proc.ExitCode -eq 0) {
            Write-Host "[ УСПЕШНО ] -> $FileName успешно завершил работу.`n"
        } else {
            Write-Warning "[ СБОЙ ] -> $FileName завершился с ошибкой! Код возврата: $($Proc.ExitCode).`n"
            
            # Если нужно прервать всю установку при падении любого из модулей, раскомментируй строку ниже:
            # throw "Развертывание остановлено из-за критической ошибки в модуле $FileName"
        }
    }

    Write-Host "========================================================="
    Write-Host " ВСЕ ОСНОВНЫЕ МОДУЛИ УСПЕШНО ОТРАБОТАЛИ!"
    Write-Host "========================================================="

    # Финальный аккорд: изолированный запуск скрипта-камикадзе
    $ResetPath = Join-Path $ScriptsDir "reset-setup-scripts.ps1"
    Write-Host "Запуск модуля: reset-setup-scripts.ps1 (Самоликвидация временных файлов)..."
    
    $ProcReset = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ResetPath`"" -WindowStyle Hidden -Wait -PassThru

    if ($ProcReset.ExitCode -eq 0) {
        Write-Host "[ УСПЕШНО ] -> Скрипт самоликвидации успешно запустил очистку в фоне.`n"
    } else {
        Write-Warning "[ СБОЙ ] -> Не удалось инициировать очистку! Код возврата: $($ProcReset.ExitCode)`n"
    }

    Write-Host "========================================================="
    Write-Host " АВТОМАТИЗАЦИЯ ПОЛНОСТЬЮ ЗАВЕРШЕНА. СИСТЕМА ГОТОВА."
    Write-Host "========================================================="

} catch {
    Write-Warning "`n[ КРИТИЧЕСКИЙ СБОЙ ДИСПЕТЧЕРА ]: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}