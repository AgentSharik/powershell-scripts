# =========================================================================
# Назначение: Модернизированный GUI Диспетчер автоматизации
# Режим: Безрамочный, Кастомные кнопки, Таймер-запуск
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# --- СКРЫТИЕ КОНСОЛИ ---
$Win32Code = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
'@
$WindowManager = Add-Type -MemberDefinition $Win32Code -Name "Win32ShowWindow" -Namespace "Win32" -PassThru
$ConsoleHandle = $WindowManager::GetConsoleWindow()
if ($ConsoleHandle -ne [System.IntPtr]::Zero) { $null = $WindowManager::ShowWindow($ConsoleHandle, 0) }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- ГЛАВНАЯ ФОРМА ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = " " 
$Form.Size = New-Object System.Drawing.Size(960, 480)
$Form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
$Form.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None 
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.MaximizeBox = $false

# Начинаем компоновку
$Form.SuspendLayout()

# --- ЛОГИКА ПЕРЕТАСКИВАНИЯ ---
$Global:MouseIsDown = $false
$Global:MouseOffset = New-Object System.Drawing.Point

# --- ШАПКА ---
$HeaderPanel = New-Object System.Windows.Forms.Panel
$HeaderPanel.Size = New-Object System.Drawing.Size(960, 60)
$HeaderPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$HeaderPanel.Add_MouseDown({
    $Global:MouseIsDown = $true
    $Global:MouseOffset = New-Object System.Drawing.Point($_.X, $_.Y)
})
$HeaderPanel.Add_MouseMove({
    if ($Global:MouseIsDown) {
        $Form.Location = New-Object System.Drawing.Point(($Form.Left + $_.X - $Global:MouseOffset.X), ($Form.Top + $_.Y - $Global:MouseOffset.Y))
    }
})
$HeaderPanel.Add_MouseUp({ $Global:MouseIsDown = $false })
$Form.Controls.Add($HeaderPanel)

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Менеджер автоматической настройки"
$TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.FontStyle]::Bold)
$TitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
$TitleLabel.AutoSize = $true
$HeaderPanel.Controls.Add($TitleLabel)

# Кнопки управления
$CloseBtn = New-Object System.Windows.Forms.Label
$CloseBtn.Text = "×"; $CloseBtn.Size = New-Object System.Drawing.Size(40, 60); $CloseBtn.Location = New-Object System.Drawing.Point(920, 0)
$CloseBtn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$CloseBtn.Font = New-Object System.Drawing.Font("Segoe UI", 20)
$CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
$CloseBtn.Add_MouseEnter({ $CloseBtn.BackColor = [System.Drawing.Color]::FromArgb(243, 139, 168); $CloseBtn.ForeColor = [System.Drawing.Color]::White })
$CloseBtn.Add_MouseLeave({ $CloseBtn.BackColor = [System.Drawing.Color]::Transparent; $CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244) })
$CloseBtn.Add_Click({ $Form.Close() })
$HeaderPanel.Controls.Add($CloseBtn)

$MinBtn = New-Object System.Windows.Forms.Label
$MinBtn.Text = "—"; $MinBtn.Size = New-Object System.Drawing.Size(40, 60); $MinBtn.Location = New-Object System.Drawing.Point(880, 0)
$MinBtn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$MinBtn.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$MinBtn.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
$MinBtn.Add_MouseEnter({ $MinBtn.BackColor = [System.Drawing.Color]::FromArgb(88, 91, 112) })
$MinBtn.Add_MouseLeave({ $MinBtn.BackColor = [System.Drawing.Color]::Transparent })
$MinBtn.Add_Click({ $Form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized })
$HeaderPanel.Controls.Add($MinBtn)

# --- ЭЛЕМЕНТЫ ФОРМЫ ---
$TasksContainer = New-Object System.Windows.Forms.Panel
$TasksContainer.Location = New-Object System.Drawing.Point(20, 80); $TasksContainer.Size = New-Object System.Drawing.Size(540, 200)
$TasksContainer.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$Form.Controls.Add($TasksContainer)

$LogContainer = New-Object System.Windows.Forms.Panel
$LogContainer.Location = New-Object System.Drawing.Point(580, 80); $LogContainer.Size = New-Object System.Drawing.Size(340, 275)
$LogContainer.BackColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
$Form.Controls.Add($LogContainer)

$LogTextBox = New-Object System.Windows.Forms.RichTextBox
$LogTextBox.Location = New-Object System.Drawing.Point(15, 15); $LogTextBox.Size = New-Object System.Drawing.Size(310, 245)
$LogTextBox.BackColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
$LogTextBox.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
$LogTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9.5, [System.Drawing.FontStyle]::Bold)
$LogTextBox.ReadOnly = $true
$LogContainer.Controls.Add($LogTextBox)

$DoneButton = New-Object System.Windows.Forms.Button
$DoneButton.Text = "ГОТОВО"; $DoneButton.Location = New-Object System.Drawing.Point(740, 380); $DoneButton.Size = New-Object System.Drawing.Size(180, 40)
$DoneButton.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 80)
$DoneButton.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$DoneButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$DoneButton.Enabled = $false
$DoneButton.Add_Click({ $Form.Close() })
$Form.Controls.Add($DoneButton)

function Add-LogLine ($Prefix, $Message, $ColorRGB = @(166, 173, 200)) {
    $Time = (Get-Date).ToString("HH:mm:ss")
    $LogTextBox.AppendText("[$Time] ")
    $LogTextBox.SelectionStart = $LogTextBox.TextLength
    $LogTextBox.SelectionColor = [System.Drawing.Color]::FromArgb($ColorRGB[0], $ColorRGB[1], $ColorRGB[2])
    $LogTextBox.AppendText("[$Prefix] $Message`r`n")
    $LogTextBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

$ScriptsToRun = @(
    @{ Name = "clean-and-photo.ps1"; Title = "Оптимизация ОС" },
    @{ Name = "install-sys-components.ps1"; Title = "Системные компоненты" },
    @{ Name = "apps-install.ps1"; Title = "Установка софта" },
    @{ Name = "office-install.ps1"; Title = "Установка Office" }
)

$ScriptControls = @()
$YOffset = 15
foreach ($Script in $ScriptsToRun) {
    $TaskLabel = New-Object System.Windows.Forms.Label
    $TaskLabel.Text = $Script.Title; $TaskLabel.Location = New-Object System.Drawing.Point(20, $YOffset); $TaskLabel.Size = New-Object System.Drawing.Size(360, 25)
    $TasksContainer.Controls.Add($TaskLabel)
    
    $StatusLabel = New-Object System.Windows.Forms.Label
    $StatusLabel.Text = "• Ожидание"; $StatusLabel.Location = New-Object System.Drawing.Point(400, $YOffset); $StatusLabel.Size = New-Object System.Drawing.Size(130, 25)
    $TasksContainer.Controls.Add($StatusLabel)
    $ScriptControls += [PSCustomObject]@{ StatusLabel = $StatusLabel }
    $YOffset += 40
}

$CurrentActionLabel = New-Object System.Windows.Forms.Label
$CurrentActionLabel.Text = "Инициализация..."; $CurrentActionLabel.Location = New-Object System.Drawing.Point(20, 300); $CurrentActionLabel.Size = New-Object System.Drawing.Size(540, 25)
$Form.Controls.Add($CurrentActionLabel)

$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(20, 330); $ProgressBar.Size = New-Object System.Drawing.Size(540, 25); $ProgressBar.Maximum = $ScriptsToRun.Count
$Form.Controls.Add($ProgressBar)

# --- ЛОГИКА ТАЙМЕРА (ЗАПУСК) ---
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 500
$Timer.Add_Tick({
    $Timer.Stop()
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    
    for ($i = 0; $i -lt $ScriptsToRun.Count; $i++) {
        $Script = $ScriptsToRun[$i]; $Controls = $ScriptControls[$i]; $ScriptPath = Join-Path $ScriptsDir $Script.Name
        $Controls.StatusLabel.Text = "▶ Выполняется..."
        $CurrentActionLabel.Text = "Обработка: $($Script.Name)..."
        
        if (Test-Path $ScriptPath) {
            $Proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -WindowStyle Hidden -PassThru
            while (-not $Proc.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
            if ($Proc.ExitCode -eq 0) { $Controls.StatusLabel.Text = "✓ Готово"; Add-LogLine " OK " "$($Script.Name) завершен" @(166, 227, 161) }
            else { $Controls.StatusLabel.Text = "✗ Сбой"; Add-LogLine "FAIL" "Код ошибки: $($Proc.ExitCode)" @(243, 139, 168) }
        }
        $ProgressBar.Value = $i + 1
    }
    $CurrentActionLabel.Text = "Все задачи завершены."
    $DoneButton.Enabled = $true; $DoneButton.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250); $DoneButton.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
})

# Запуск таймера после показа формы
$Form.Add_Shown({ $Timer.Start() })
$Form.ResumeLayout()

[System.Windows.Forms.Application]::Run($Form)
