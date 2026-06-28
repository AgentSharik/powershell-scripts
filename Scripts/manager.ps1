# =========================================================================
# Назначение: Исправленный GUI Диспетчер (режим STA)
# Убрано скрытие консоли для стабильной работы GUI
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# --- ФУНКЦИЯ ПРИНУДИТЕЛЬНОГО ВЫХОДА ---
function Exit-Application {
    # Сначала закрываем форму
    $Form.Close()
    # Убиваем текущий процесс, чтобы не плодить "зомби"
    Stop-Process -Id $PID -Force
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
Start-Transcript -Path (Join-Path $LogDir "Main_Setup_GUI_Dispatcher.log") -Append

# --- СПИСОК ОПЕРАЦИЙ ---
$ScriptsToRun = @(
    @{ Name = "clean-and-photo.ps1";        Title = "Оптимизация ОС и просмотр фото";     Status = "Ожидание" },
    @{ Name = "install-sys-components.ps1"; Title = "Установка системных компонентов";     Status = "Ожидание" },
    @{ Name = "apps-install.ps1";           Title = "Установка софта";                     Status = "Ожидание" },
    @{ Name = "office-install.ps1";         Title = "Установка и активация Microsoft Office"; Status = "Ожидание" }
)

# --- GUI ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = " Автоматическая настройка системы"
$Form.Size = New-Object System.Drawing.Size(960, 480)
$Form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
$Form.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.MaximizeBox = $false
$Form.TopMost = $true # Чтобы окно гарантированно вылезло поверх всех

# Шапка
$HeaderPanel = New-Object System.Windows.Forms.Panel
$HeaderPanel.Size = New-Object System.Drawing.Size(960, 60)
$HeaderPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$Form.Controls.Add($HeaderPanel)

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Менеджер автоматической настройки"
$TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, 1)
$TitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
$TitleLabel.AutoSize = $true
$HeaderPanel.Controls.Add($TitleLabel)

# Контейнер задач
$TasksContainer = New-Object System.Windows.Forms.Panel
$TasksContainer.Location = New-Object System.Drawing.Point(20, 80)
$TasksContainer.Size = New-Object System.Drawing.Size(540, 200)
$TasksContainer.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$Form.Controls.Add($TasksContainer)

# Панель лога
$LogContainer = New-Object System.Windows.Forms.Panel
$LogContainer.Location = New-Object System.Drawing.Point(580, 80)
$LogContainer.Size = New-Object System.Drawing.Size(340, 275)
$LogContainer.BackColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
$Form.Controls.Add($LogContainer)

$LogTextBox = New-Object System.Windows.Forms.RichTextBox
$LogTextBox.Location = New-Object System.Drawing.Point(15, 15)
$LogTextBox.Size = New-Object System.Drawing.Size(310, 245)
$LogTextBox.BackColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
$LogTextBox.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
$LogTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9.5, 1)
$LogTextBox.ReadOnly = $true
$LogTextBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$LogContainer.Controls.Add($LogTextBox)

# --- КНОПКА ГОТОВО ---
$DoneButton = New-Object System.Windows.Forms.Button
$DoneButton.Text = "ГОТОВО"
$DoneButton.Location = New-Object System.Drawing.Point(740, 380)
$DoneButton.Size = New-Object System.Drawing.Size(180, 40)
$DoneButton.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$DoneButton.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$DoneButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$DoneButton.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, 1)
$DoneButton.Visible = $false
$DoneButton.Add_Click({ Exit-Application })
$Form.Controls.Add($DoneButton)

function Add-LogLine ($Prefix, $Message, $ColorRGB = @(166, 173, 200)) {
    $Time = (Get-Date).ToString("HH:mm:ss")
    $LogTextBox.SelectionStart = $LogTextBox.TextLength
    $LogTextBox.SelectionColor = [System.Drawing.Color]::FromArgb(108, 112, 134)
    $LogTextBox.AppendText("[$Time] ")
    $LogTextBox.SelectionStart = $LogTextBox.TextLength
    $LogTextBox.SelectionColor = [System.Drawing.Color]::FromArgb($ColorRGB[0], $ColorRGB[1], $ColorRGB[2])
    $LogTextBox.AppendText("[$Prefix] ")
    $LogTextBox.SelectionStart = $LogTextBox.TextLength
    $LogTextBox.SelectionColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $LogTextBox.AppendText("$Message`r`n")
    $LogTextBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# Отрисовка задач
$ScriptControls = @()
$YOffset = 15
for ($i = 0; $i -lt $ScriptsToRun.Count; $i++) {
    $CurrentScript = $ScriptsToRun[$i]
    $TaskLabel = New-Object System.Windows.Forms.Label
    $TaskLabel.Text = $CurrentScript.Title
    $TaskLabel.Location = New-Object System.Drawing.Point(20, $YOffset)
    $TaskLabel.Size = New-Object System.Drawing.Size(360, 25)
    $TaskLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $TasksContainer.Controls.Add($TaskLabel)

    $StatusLabel = New-Object System.Windows.Forms.Label
    $StatusLabel.Text = "• Ожидание"
    $StatusLabel.Location = New-Object System.Drawing.Point(400, $YOffset)
    $StatusLabel.Size = New-Object System.Drawing.Size(130, 25)
    $StatusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, 1)
    $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $TasksContainer.Controls.Add($StatusLabel)

    $ScriptControls += [PSCustomObject]@{ StatusLabel = $StatusLabel }
    $YOffset += 40
}

$CurrentActionLabel = New-Object System.Windows.Forms.Label
$CurrentActionLabel.Text = "Инициализация..."
$CurrentActionLabel.Location = New-Object System.Drawing.Point(20, 300)
$CurrentActionLabel.Size = New-Object System.Drawing.Size(540, 25)
$Form.Controls.Add($CurrentActionLabel)

$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(20, 330)
$ProgressBar.Size = New-Object System.Drawing.Size(540, 25)
$ProgressBar.Maximum = $ScriptsToRun.Count
$Form.Controls.Add($ProgressBar)

# --- ЛОГИКА ---
$Form.Add_Shown({
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    $Cyan = @(137, 220, 235); $Purple = @(203, 166, 247); $Green = @(166, 227, 161); $Red = @(243, 139, 168); $Yellow = @(249, 226, 175)

    Add-LogLine "CORE" "Запуск планировщика..." $Cyan
    
    for ($i = 0; $i -lt $ScriptsToRun.Count; $i++) {
        $Script = $ScriptsToRun[$i]; $Controls = $ScriptControls[$i]; $ScriptPath = Join-Path $ScriptsDir $Script.Name
        $Controls.StatusLabel.Text = "▶ Выполняется..."
        $Controls.StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(137, 220, 235)
        $CurrentActionLabel.Text = "Обработка: $($Script.Name)..."
        
        if (Test-Path $ScriptPath) {
            # Запускаем в новом процессе
            $Proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -WindowStyle Hidden -PassThru
            while (-not $Proc.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
            if ($Proc.ExitCode -eq 0) {
                $Controls.StatusLabel.Text = "✓ Готово"; $Controls.StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
                Add-LogLine " OK " "Модуль завершен." $Green
            } else {
                $Controls.StatusLabel.Text = "✗ Сбой"; $Controls.StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
                Add-LogLine "FAIL" "Ошибка кода: $($Proc.ExitCode)" $Red
            }
        }
        $ProgressBar.Value = $i + 1
        [System.Windows.Forms.Application]::DoEvents()
    }

    $CurrentActionLabel.Text = "Все задачи завершены."
    Add-LogLine "DONE" "Настройка окончена." $Green
    $DoneButton.Visible = $true 
})

# Запуск
[System.Windows.Forms.Application]::Run($Form)
Stop-Transcript
