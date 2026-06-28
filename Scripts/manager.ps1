# =========================================================================
# Назначение: Модернизированный GUI Диспетчер автоматизации (Modern Dark UI)
# Режим запуска: Полностью скрытый для дочерних процессов
# Кодировка: UTF-8 с BOM (Обязательно для корректной кириллицы)
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Подгружаем библиотеки графического интерфейса Windows
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Настройка логирования
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
Start-Transcript -Path (Join-Path $LogDir "Main_Setup_GUI_Dispatcher.log") -Append

# --- СПИСОК ОПЕРАЦИЙ ---
$ScriptsToRun = @(
    @{ Name = "clean-and-photo.ps1";        Title = "Очистка системы и кэша фото";     Status = "Ожидание" },
    @{ Name = "install-sys-components.ps1"; Title = "Установка системных компонентов"; Status = "Ожидание" },
    @{ Name = "apps-install.ps1";           Title = "Развертывание базового софта";    Status = "Ожидание" },
    @{ Name = "office-install.ps1";         Title = "Инсталляция офисного пакета";     Status = "Ожидание" }
)

# --- СОЗДАНИЕ И СТИЛИЗАЦИЯ GUI ИНТЕРФЕЙСА (DARK MODE) ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = " Системная автоматизация Windows"
$Form.Size = New-Object System.Drawing.Size(650, 480)
$Form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37) # Глубокий темный
$Form.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244) # Бело-серый текст
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.MaximizeBox = $false

# Шапка (Заголовок)
$HeaderPanel = New-Object System.Windows.Forms.Panel
$HeaderPanel.Size = New-Object System.Drawing.Size(650, 60)
$HeaderPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$Form.Controls.Add($HeaderPanel)

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "WINDOWS OS DEPLOYMENT MANAGER"
$TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold)
$TitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250) # Приятный синий акцент
$TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
$TitleLabel.AutoSize = $true
$HeaderPanel.Controls.Add($TitleLabel)

# Общий контейнер для списка задач
$TasksContainer = New-Object System.Windows.Forms.Panel
$TasksContainer.Location = New-Object System.Drawing.Point(20, 80)
$TasksContainer.Size = New-Object System.Drawing.Size(595, 200)
$TasksContainer.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$Form.Controls.Add($TasksContainer)

# Отрисовка элементов задач на панели
$ScriptControls = @()
$YOffset = 15

for ($i = 0; $i -lt $ScriptsToRun.Count; $i++) {
    $CurrentScript = $ScriptsToRun[$i]

    # Текст задачи
    $TaskLabel = New-Object System.Windows.Forms.Label
    $TaskLabel.Text = $CurrentScript.Title
    $TaskLabel.Location = New-Object System.Drawing.Point(20, $YOffset)
    $TaskLabel.Size = New-Object System.Drawing.Size(400, 25)
    $TaskLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $TasksContainer.Controls.Add($TaskLabel)

    # Статус задачи (визуальный маркер)
    $StatusLabel = New-Object System.Windows.Forms.Label
    $StatusLabel.Text = "• Ожидание"
    $StatusLabel.Location = New-Object System.Drawing.Point(450, $YOffset)
    $StatusLabel.Size = New-Object System.Drawing.Size(130, 25)
    $StatusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200) # Серый
    $TasksContainer.Controls.Add($StatusLabel)

    # Сохраняем ссылки для динамического обновления
    $ScriptControls += [PSCustomObject]@{
        TaskLabel   = $TaskLabel
        StatusLabel = $StatusLabel
    }
    $YOffset += 40
}

# Строка текущего действия (Мини-лог)
$CurrentActionLabel = New-Object System.Windows.Forms.Label
$CurrentActionLabel.Text = "Подготовка к запуску автоматизации..."
$CurrentActionLabel.Location = New-Object System.Drawing.Point(20, 300)
$CurrentActionLabel.Size = New-Object System.Drawing.Size(595, 25)
$CurrentActionLabel.Font = New-Object System.Drawing.Font("Segoe UI Italic", 10, [System.Drawing.FontStyle]::Italic)
$CurrentActionLabel.ForeColor = [System.Drawing.Color]::FromArgb(245, 194, 231) # Розоватый акцент
$Form.Controls.Add($CurrentActionLabel)

# Нативный прогресс-бар
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(20, 330)
$ProgressBar.Size = New-Object System.Drawing.Size(595, 25)
$ProgressBar.Minimum = 0
$ProgressBar.Maximum = $ScriptsToRun.Count
$ProgressBar.Value = 0
$Form.Controls.Add($ProgressBar)

# Нижний колонтитул
# Нижний колонтитул
$FooterLabel = New-Object System.Windows.Forms.Label
$FooterLabel.Text = "Пожалуйста, не закрывайте это окно до завершения всех процессов."
$FooterLabel.Location = New-Object System.Drawing.Point(20, 380)
$FooterLabel.Size = New-Object System.Drawing.Size(595, 25)
$FooterLabel.ForeColor = [System.Drawing.Color]::FromArgb(147, 153, 178)
$FooterLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter # Исправлено здесь
$Form.Controls.Add($FooterLabel)


# --- ЛОГИКА АВТОМАТИЧЕСКОГО ВЫПОЛНЕНИЯ ---
$Form.Add_Shown({
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    
    for ($i = 0; $i -lt $ScriptsToRun.Count; $i++) {
        $Script = $ScriptsToRun[$i]
        $Controls = $ScriptControls[$i]
        $ScriptPath = Join-Path $ScriptsDir $Script.Name

        # 1. Обновляем статус на "Выполняется"
        $Controls.StatusLabel.Text = "▶ Выполняется..."
        $Controls.StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(137, 220, 235) # Бирюзовый
        $CurrentActionLabel.Text = "Выполняется фоновый модуль: $($Script.Name)..."
        
        # Перерисовываем интерфейс, чтобы избежать зависания формы
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 300 # Небольшая пауза для визуальной плавности

        if (Test-Path $ScriptPath) {
            try {
                # ИЗМЕНЕНО: Параметр -WindowStyle изменен на Hidden. Дочернее окно PowerShell теперь не появится.
                $Proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -WindowStyle Hidden -Wait -PassThru
                
                if ($Proc.ExitCode -eq 0) {
                    $Controls.StatusLabel.Text = "✓ Готово"
                    $Controls.StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161) # Зеленый
                } else {
                    $Controls.StatusLabel.Text = "✗ Сбой (Код: $($Proc.ExitCode))"
                    $Controls.StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168) # Красный
                }
            } catch {
                $Controls.StatusLabel.Text = "✗ Критическая ошибка"
                $Controls.StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
            }
        } else {
            $Controls.StatusLabel.Text = "⚠ Отсутствует"
            $Controls.StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(249, 226, 175) # Желтый
        }

        # Обновляем общий прогресс
        $ProgressBar.Value = $i + 1
        [System.Windows.Forms.Application]::DoEvents()
    }

    # --- ЗАВЕРШАЮЩИЙ ЭТАП ---
    $CurrentActionLabel.Text = "Все основные задачи обработаны. Запуск очистки..."
    $CurrentActionLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Seconds 2

    $ResetPath = Join-Path $ScriptsDir "reset-setup-scripts.ps1"
    if (Test-Path $ResetPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ResetPath`"" -WindowStyle Hidden
    }

    # Автоматически закрываем красивое меню по завершении
    Start-Sleep -Seconds 1
    $Form.Close()
})

# Запуск приложения графического интерфейса
[System.Windows.Forms.Application]::Run($Form)
Stop-Transcript
