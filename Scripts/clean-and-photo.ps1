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
    # ЭТАП 2: АКТИВАЦИЯ КЛАССИЧЕСКОГО ПРОСМОТРА ФОТО
    # ----------------------------------------------------
    Write-Host ">>> Активация Просмотра фотографий Windows 7..."
    
    # 1) Включаем ассоциации в HKLM
    $assocPath = "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations"
    if (-not (Test-Path $assocPath)) { New-Item -Path $assocPath -Force | Out-Null }
    @(".jpg",".jpeg",".png",".bmp",".gif",".tif",".tiff",".jfif",".wdp") | ForEach-Object {
        Set-ItemProperty -Path $assocPath -Name $_ -Value "PhotoViewer.FileAssoc.Tiff" -Force
    }

    # 2) Создаём DefaultAppAssociations.xml для DISM
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

    # 3) Импорт через DISM
    $dismArgs = @("/Online", "/Import-DefaultAppAssociations:$daaPath")
    $p = Start-Process -FilePath "dism.exe" -ArgumentList $dismArgs -PassThru -Wait -NoNewWindow
    if ($p.ExitCode -ne 0) { throw "DISM завершился с кодом $($p.ExitCode)." }

    # 4) Регистрация в RegisteredApplications
    Set-ItemProperty -Path "HKLM:\SOFTWARE\RegisteredApplications" -Name "Windows Photo Viewer" -Value "SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities" -Force
    
    Write-Host ">>> Просмотр фотографий успешно настроен по умолчанию!"

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
    # ЭТАП 4: ОТЛОЖЕННЫЙ СБРОС ЦЕНТРА ОБНОВЛЕНИЙ (Через 1 час)
    # ----------------------------------------------------
    Write-Host ">>> Создание отложенной задачи для фикса WaaS-reset..."
    
    # Создаем скрытую временную папку, которая доживет до запуска задачи
    $FixDir = "$env:ProgramData\WaaS_Fix"
    if (-not (Test-Path $FixDir)) { New-Item -ItemType Directory -Force -Path $FixDir | Out-Null }
    
    $WaaS_RegFilePath = Join-Path $FixDir "waas.reg"
    $WaaS_ScriptPath  = Join-Path $FixDir "run_fix.ps1"
    $TaskName = "WaaS_Reset_Delayed"
    
    # 1. Создаем сам reg-файл с твиком
    $WaaS_RegContent = @'
Windows Registry Editor Version 5.00

[-HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WaaSAssessment]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WaaSAssessment]
"Endpoint"="settings-win.data.microsoft.com"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WaaSAssessment\Cache]
"UpToDateStatus"=dword:00000000
"UpToDateImpact"=dword:00000000
"UpToDateDays"=dword:00000000
'@
    [System.IO.File]::WriteAllText($WaaS_RegFilePath, $WaaS_RegContent, [System.Text.Encoding]::UTF8)
    
    # 2. Создаем скрипт-чистильщик. Он импортирует реестр, удалит задачу в планировщике и сотрет эту временную папку.
    $ScriptContent = @"
reg.exe import `"$WaaS_RegFilePath`"
Unregister-ScheduledTask -TaskName `"$TaskName`" -Confirm:`$false
Start-Sleep -Seconds 2
Remove-Item -Path `"$FixDir`" -Recurse -Force
"@
    [System.IO.File]::WriteAllText($WaaS_ScriptPath, $ScriptContent, [System.Text.Encoding]::UTF8)
    
    # 3. Настраиваем Планировщик задач
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$WaaS_ScriptPath`""
    
    # Считаем время: текущее + 1 час
    $TriggerTime = (Get-Date).AddHours(1)
    $Trigger = New-ScheduledTaskTrigger -Once -At $TriggerTime
    
    # Выполнять от имени СИСТЕМЫ (наивысшие права, работает в фоне без окон)
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # StartWhenAvailable - ВАЖНАЯ настройка! Если ПК через час будет выключен, задача сработает при первом же включении
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    $Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force | Out-Null
    
    Write-Host ">>> Отложенная задача '$TaskName' создана! Сработает незаметно в $($TriggerTime.ToString('HH:mm')) и удалит сама себя."

} catch {
    Write-Warning "Ошибка во время оптимизации: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}
