# =========================================================================
# Имя файла: clean-and-photo.ps1
# Назначение: Очистка системы, настройка Photo Viewer, оптимизация файла подкачки 
#             и отложенный сброс ошибок Центра обновлений (WaaS)
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Логи в Документы Администратора (поддерживает русское имя пользователя)
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
Start-Transcript -Path (Join-Path $LogDir "System_Optimization.log") -Append

try {
    # ----------------------------------------------------
    # ЭТАП 1: ГЛУБОКАЯ ОЧИСТКА СИСТЕМЫ ОТ МУСОРА (DEBLOAT)
    # ----------------------------------------------------
    Write-Host ">>> Начало очистки встроенного мусора..."

    # Список масок приложений, которые нужно УДАЛИТЬ БЕЗЖАЛОСТНО
    $BloatList = @(
        "Yandex.Music",                 # Превентивное удаление Яндекс.Музыки
        "Microsoft.ZuneMusic",          # Музыка Groove (Groove Music) - СНОСИМ!
        "office.outlook",               # Новый Outlook
        "windowscommunicationsapps",    # Почта и Календарь
        "Microsoft.3DViewer",           # 3D Просмотрщик
        "Microsoft.MixedReality.Portal",# Portal смешанной реальности
        "Microsoft.BingNews",           # Новости
        "Microsoft.BingWeather",        # Погода
        "Microsoft.BingFinance",        # Финансы
        "Microsoft.BingSports",         # Спорт
        "Microsoft.MicrosoftSolitaireCollection", # Пасьянсы с рекламой
        "Microsoft.WindowsFeedbackHub", # Центр отзывов (Телеметрия)
        "Microsoft.GetHelp",            # Справка / Получить помощь
        "Microsoft.Getstarted",         # Советы / Начало работы
        "Microsoft.YourPhone",          # Связь с телефоном
        "Microsoft.MicrosoftTeams",     # Teams
        "Microsoft.SkypeApp",           # Skype
        "Microsoft.54958562F4433"       # Clipchamp (Видеоредактор)
    )

    foreach ($App in $BloatList) {
        Write-Host "Удаление пакета: $App"
        # Удаляем у текущих пользователей
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -match $App } | Remove-AppxPackage -ErrorAction SilentlyContinue
        # Удаляем из заготовок системы (чтобы не вернулся при обновлениях)
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match $App } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
    Write-Host ">>> Очистка UWP-приложений завершена."

    # Полное удаление OneDrive из системы
    Write-Host ">>> Удаление OneDrive..."
    Stop-Process -Name 'OneDrive' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") { Start-Process "$env:SystemRoot\System32\OneDriveSetup.exe" -ArgumentList '/uninstall' -Wait }
    if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList '/uninstall' -Wait }

    # ----------------------------------------------------
    # ЭТАП 2: РЕГИСТРАЦИЯ ПРОСМОТРА ФОТОГРАФИЙ
    # ----------------------------------------------------
    Write-Host ">>> Регистрация Просмотра фотографий..."
    
    $associations = @(".jpg", ".jpeg", ".bmp", ".dib", ".gif", ".jfif", ".jpe", ".png", ".tif", ".tiff", ".wdp")
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations"

    if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

    foreach ($ext in $associations) {
        New-ItemProperty -Path $regPath -Name $ext -Value "PhotoViewer.FileAssoc.Tiff" -PropertyType String -Force | Out-Null
    }
    
    # Это важно: без этой строчки приложение может не появиться в списке выбора
    Set-ItemProperty -Path "HKLM:\SOFTWARE\RegisteredApplications" -Name "Windows Photo Viewer" -Value "SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities" -Force
    
    Write-Host ">>> Регистрация завершена. Теперь в 'Открыть с помощью' должен появиться 'Просмотр фотографий Windows'." -ForegroundColor Green
    # ----------------------------------------------------
    # ЭТАП 3: ОПТИМИЗАЦИЯ ФАЙЛА ПОДКАЧКИ (ЧЕРЕЗ РЕЕСТР)
    # ----------------------------------------------------
    Write-Host ">>> Проверка ОЗУ и конфигурация файла подкачки..."
    
    $RAM_KB = (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize
    $Threshold_KB = 32505856

    # Снимаем галочку "Автоматически выбирать объем файла подкачки"
    Set-CimInstance -Query "Select * from Win32_ComputerSystem" -Property @{ AutomaticManagedPagefile = $False }

    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

    if ($RAM_KB -ge $Threshold_KB) {
        Write-Host "RAM >= 32GB. Полное отключение файла подкачки (Pagefile)..."
        Set-ItemProperty -Path $RegPath -Name "PagingFiles" -Value @("") -Type MultiString -Force
    } else {
        Write-Host "RAM <= 31GB. Установка фиксированного файла подкачки размером 8 ГБ..."
        $PageFileString = "C:\pagefile.sys 8192 8192"
        Set-ItemProperty -Path $RegPath -Name "PagingFiles" -Value @($PageFileString) -Type MultiString -Force
    }
    Write-Host ">>> Конфигурация памяти завершена успешно! Изменения вступят в силу после перезагрузки ПК."

# ----------------------------------------------------
    # ЭТАП 4: ФИКС WaaS + АВТОУДАЛЕНИЕ ПАПКИ
    # ----------------------------------------------------
    Write-Host ">>> Подготовка фикса..."
    
    $FixDir = "C:\ProgramData\WaaS_Fix"
    if (-not (Test-Path $FixDir)) { New-Item -ItemType Directory -Force -Path $FixDir | Out-Null }
    
    $RegPath = Join-Path $FixDir "WaaS-reset.reg"
    $CmdPath = Join-Path $FixDir "apply_fix.cmd"
    $TaskName = "WaaS_Reset_60min"
    
    # 1. Файл реестра
    $RegContent = @"
Windows Registry Editor Version 5.00

[-HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WaaSAssessment]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WaaSAssessment]
"Endpoint"="settings-win.data.microsoft.com"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WaaSAssessment\Cache]
"UpToDateStatus"=dword:00000000
"UpToDateImpact"=dword:00000000
"UpToDateDays"=dword:00000000
"@
    $RegContent | Out-File -FilePath $RegPath -Encoding Unicode
    
    # 2. CMD-файл с выходом из папки перед удалением
    $CmdContent = @"
@echo off
:: Импортируем реестр используя полный путь
reg import "$RegPath"

:: Удаляем задачу из планировщика
schtasks /delete /tn "$TaskName" /f

:: ВАЖНО: Выходим из папки перед её удалением
cd /d C:\

:: Удаляем всю папку с фиксами
rd /s /q "$FixDir"
"@
    [System.IO.File]::WriteAllText($CmdPath, $CmdContent, [System.Text.Encoding]::UTF8)
    
    # 3. Задача
    $Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$CmdPath`""
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(60)
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    
    $Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force | Out-Null
    
    Write-Host ">>> Готово. Папка и задача удалятся автоматически через 60 минут."

} catch {
    Write-Warning "Ошибка: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}
