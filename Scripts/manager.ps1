# =========================================================================
# Назначение: Модернизированный GUI Диспетчер автоматизации (Cyberpunk UI)
# Режим запуска: Полное скрытие собственного окна консоли + Живой не лагающий GUI
# Кодировка: UTF-8 с BOM (Обязательно для корректной кириллицы)
# =========================================================================
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# --- 1. СКРЫТИЕ КОНСОЛИ ---
$Win32Code = @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
[DllImport("user32.dll")] public static extern bool ReleaseCapture();
'@
$WindowManager = Add-Type -MemberDefinition $Win32Code -Name "Win32Native" -Namespace "Win32" -PassThru
$ConsoleHandle = $WindowManager::GetConsoleWindow()
if ($ConsoleHandle -ne [System.IntPtr]::Zero) { $null = $WindowManager::ShowWindow($ConsoleHandle, 0) }

# Подгружаем библиотеки графического интерфейса
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Настройка логирования (Транскрипт пишется в фон)
$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }

# --- 2. ФУНКЦИЯ ДИАЛОГА ВЫХОДА ---
function Show-ExitDialog {
    $Diag = New-Object System.Windows.Forms.Form
    $Diag.Size = New-Object System.Drawing.Size(500, 300)
    $Diag.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $Diag.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $Diag.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)

    $DragAction = {
        param($sender, $e)
        if ($e.Button -eq 'Left') {
            [Win32.Win32Native]::ReleaseCapture()
            [Win32.Win32Native]::SendMessage($Diag.Handle, 0xA1, 0x2, 0)
        }
    }
    $Diag.Add_MouseDown($DragAction)

    $Border = New-Object System.Windows.Forms.Panel
    $Border.Size = New-Object System.Drawing.Size(496, 296)
    $Border.Location = New-Object System.Drawing.Point(2, 2)
    $Border.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $Border.Add_MouseDown($DragAction)
    $Diag.Controls.Add($Border)

    $Title = New-Object System.Windows.Forms.Label
    $Title.Text = "СИСТЕМА НАСТРОЕНА"
    $Title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold)
    $Title.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
    $Title.Location = New-Object System.Drawing.Point(30, 30)
    $Title.AutoSize = $true
    $Title.Add_MouseDown($DragAction)
    $Border.Controls.Add($Title)

    $Msg = New-Object System.Windows.Forms.Label
    $Msg.Text = "Все операции успешно отработали. Для корректного завершения процесса установки перезагрузите ПК."
    $Msg.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $Msg.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $Msg.Location = New-Object System.Drawing.Point(30, 80)
    $Msg.Size = New-Object System.Drawing.Size(440, 60)
    $Msg.Add_MouseDown($DragAction)
    $Border.Controls.Add($Msg)

    $BtnGit = New-Object System.Windows.Forms.Button
    $BtnGit.Text = "GITHUB РАЗРАБОТЧИКА"
    $BtnGit.Location = New-Object System.Drawing.Point(30, 160)
    $BtnGit.Size = New-Object System.Drawing.Size(440, 45)
    $BtnGit.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
    $BtnGit.ForeColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $BtnGit.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $BtnGit.FlatAppearance.BorderSize = 0
    $BtnGit.Cursor = [System.Windows.Forms.Cursors]::Hand
    $BtnGit.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $BtnGit.Add_Click({ [System.Diagnostics.Process]::Start("https://github.com/alexejnekrasov/powershell-scripts/tree/main") })
    $Border.Controls.Add($BtnGit)

    $BtnOk = New-Object System.Windows.Forms.Button
    $BtnOk.Text = "ВЫХОД"
    $BtnOk.Location = New-Object System.Drawing.Point(30, 220)
    $BtnOk.Size = New-Object System.Drawing.Size(440, 40)
    $BtnOk.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $BtnOk.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $BtnOk.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $BtnOk.FlatAppearance.BorderSize = 0
    $BtnOk.Cursor = [System.Windows.Forms.Cursors]::Hand
    $BtnOk.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $BtnOk.Add_Click({ $Diag.Close() })
    $Border.Controls.Add($BtnOk)

    $Diag.ShowDialog() | Out-Null
}

# --- 3. ДАННЫЕ ЗАДАЧ ---
$ScriptsToRun = @(
    [PSCustomObject]@{ Name = "clean-and-photo.ps1";        Title = "Оптимизация ОС и просмотр фото";        LogName = "Запуск оптимизации ОС";    LabelRef = $null },
    [PSCustomObject]@{ Name = "install-sys-components.ps1"; Title = "Установка системных компонентов"; LogName = "Настройка компонентов";  LabelRef = $null },
    [PSCustomObject]@{ Name = "apps-install.ps1";           Title = "Установка софта";                 LogName = "Установка ПО";             LabelRef = $null },
    [PSCustomObject]@{ Name = "office-install.ps1";         Title = "Установка и активация Microsoft Office"; LogName = "Установка Office";         LabelRef = $null }
)

# --- 4. ОСНОВНАЯ ФОРМА ---
$Form = New-Object System.Windows.Forms.Form
$Form.Size = New-Object System.Drawing.Size(580, 480)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46) 

$Form.Add_FormClosing({ Show-ExitDialog })

$MainDragAction = {
    param($sender, $e)
    if ($e.Button -eq 'Left') {
        [Win32.Win32Native]::ReleaseCapture()
        [Win32.Win32Native]::SendMessage($Form.Handle, 0xA1, 0x2, 0)
    }
}
$Form.Add_MouseDown($MainDragAction)

$MainPanel = New-Object System.Windows.Forms.Panel
$MainPanel.Size = New-Object System.Drawing.Size(576, 476)
$MainPanel.Location = New-Object System.Drawing.Point(2, 2)
$MainPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
$MainPanel.Add_MouseDown($MainDragAction)
$Form.Controls.Add($MainPanel)

# Главный Заголовок
$MainTitle = New-Object System.Windows.Forms.Label
$MainTitle.Text = "МЕНЕДЖЕР АВТОМАТИЧЕСКОЙ НАСТРОЙКИ"
$MainTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold)
$MainTitle.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$MainTitle.Location = New-Object System.Drawing.Point(20, 20)
$MainTitle.AutoSize = $true
$MainTitle.Add_MouseDown($MainDragAction)
$MainPanel.Controls.Add($MainTitle)

$TitleLine = New-Object System.Windows.Forms.Panel
$TitleLine.Location = New-Object System.Drawing.Point(20, 56)
$TitleLine.Size = New-Object System.Drawing.Size(540, 2)
$TitleLine.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$MainPanel.Controls.Add($TitleLine)

$CloseBtnFrame = New-Object System.Windows.Forms.Panel
$CloseBtnFrame.Size = New-Object System.Drawing.Size(32, 32)
$CloseBtnFrame.Location = New-Object System.Drawing.Point(528, 18)
$CloseBtnFrame.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$MainPanel.Controls.Add($CloseBtnFrame)

$CloseBtn = New-Object System.Windows.Forms.Label
$CloseBtn.Text = "✕"
$CloseBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
$CloseBtn.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
$CloseBtn.Location = New-Object System.Drawing.Point(2, 2)
$CloseBtn.Size = New-Object System.Drawing.Size(28, 28)
$CloseBtn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$CloseBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$CloseBtn.Add_MouseEnter({ $CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168) })
$CloseBtn.Add_MouseLeave({ $CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200) })
$CloseBtn.Add_Click({ $Form.Close() })
$CloseBtnFrame.Controls.Add($CloseBtn)

$TasksContainer = New-Object System.Windows.Forms.Panel
$TasksContainer.Location = New-Object System.Drawing.Point(20, 75)
$TasksContainer.Size = New-Object System.Drawing.Size(540, 200)
$TasksContainer.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$MainPanel.Controls.Add($TasksContainer)

$YOffset = 20
foreach ($Script in $ScriptsToRun) {
    $TaskLabel = New-Object System.Windows.Forms.Label
    $TaskLabel.Text = $Script.Title
    $TaskLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $TaskLabel.Location = New-Object System.Drawing.Point(20, $YOffset)
    $TaskLabel.Size = New-Object System.Drawing.Size(340, 25)
    $TaskLabel.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $TasksContainer.Controls.Add($TaskLabel)

    $StatusLabel = New-Object System.Windows.Forms.Label
    $StatusLabel.Text = "• Ожидание"
    $StatusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $StatusLabel.Location = New-Object System.Drawing.Point(370, $YOffset)
    $StatusLabel.Size = New-Object System.Drawing.Size(160, 25)
    $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $TasksContainer.Controls.Add($StatusLabel)
    
    $Script.LabelRef = $StatusLabel
    $YOffset += 40
}

$CurrentActionLabel = New-Object System.Windows.Forms.Label
$CurrentActionLabel.Location = New-Object System.Drawing.Point(20, 305)
$CurrentActionLabel.Size = New-Object System.Drawing.Size(540, 25)
$CurrentActionLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
$CurrentActionLabel.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$CurrentActionLabel.Text = "Инициализация подсистем..."
$MainPanel.Controls.Add($CurrentActionLabel)

# =========================================================================
# КАСТОМНЫЙ ПРОГРЕСС-БАР С АНИМАЦИЕЙ
# =========================================================================
$ProgressContainer = New-Object System.Windows.Forms.Panel
$ProgressContainer.Location = New-Object System.Drawing.Point(20, 332)
$ProgressContainer.Size = New-Object System.Drawing.Size(540, 20)
$ProgressContainer.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68) 
$MainPanel.Controls.Add($ProgressContainer)

$ProgressFill = New-Object System.Windows.Forms.Panel
$ProgressFill.Location = New-Object System.Drawing.Point(0, 0)
$ProgressFill.Size = New-Object System.Drawing.Size(0, 20)
$ProgressFill.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250) 
$ProgressContainer.Controls.Add($ProgressFill)

# АНИМАЦИЯ (БЛИК): Светлая полоска внутри заливки
$ProgressGlare = New-Object System.Windows.Forms.Label
$ProgressGlare.Size = New-Object System.Drawing.Size(60, 20)
$ProgressGlare.Location = New-Object System.Drawing.Point(-60, 0)
$ProgressGlare.BackColor = [System.Drawing.Color]::FromArgb(180, 215, 255) # Более светлый синий
$ProgressFill.Controls.Add($ProgressGlare)

$AnimTimer = New-Object System.Windows.Forms.Timer
$AnimTimer.Interval = 20 # Обновление каждые 20 мс (~50 fps)
$AnimTimer.Add_Tick({
    if ($ProgressFill.Width -gt 0) {
        $NewX = $ProgressGlare.Left + 6 # Скорость движения пикселей
        if ($NewX -gt $ProgressFill.Width) {
            $NewX = -60 # Сброс за левый край
        }
        $ProgressGlare.Left = $NewX
    }
})
$AnimTimer.Start()
# =========================================================================

$BottomWarning = New-Object System.Windows.Forms.Label
$BottomWarning.Text = "Пожалуйста, не закрывайте это окно до завершения всех процессов."
$BottomWarning.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$BottomWarning.ForeColor = [System.Drawing.Color]::FromArgb(147, 153, 178)
$BottomWarning.Location = New-Object System.Drawing.Point(0, 420)
$BottomWarning.Size = New-Object System.Drawing.Size(576, 20)
$BottomWarning.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$MainPanel.Controls.Add($BottomWarning)

# --- 5. ФУНКЦИЯ ФОНОВОГО ЛОГА ---
function Add-LogLine ($Prefix, $Message) {
    $Time = (Get-Date).ToString("HH:mm:ss")
    Write-Output "[$Time] [$Prefix] $Message"
    [System.Windows.Forms.Application]::DoEvents()
}

# Остановка таймера при закрытии (чтобы не висел в памяти)
$Form.Add_FormClosing({ $AnimTimer.Stop() })

# --- 6. ЛОГИКА АВТОМАТИЗАЦИИ ---
$Form.Add_Shown({
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    
    Add-LogLine "CORE" "Запуск планировщика..."
    
    for ($i = 0; $i -lt $ScriptsToRun.Count; $i++) {
        $Script = $ScriptsToRun[$i]
        $ScriptPath = Join-Path $ScriptsDir $Script.Name
        
        $Script.LabelRef.Text = "▶ Выполняется..."
        $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(137, 220, 235)
        $CurrentActionLabel.Text = "Запуск: $($Script.Name)..."
        
        if (Test-Path $ScriptPath) {
            try {
                $Proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -WindowStyle Hidden -PassThru
                
                while (-not $Proc.HasExited) {
                    [System.Windows.Forms.Application]::DoEvents()
                    # СНИЗИЛИ ЗАДЕРЖКУ ДО 20 МС ДЛЯ ПЛАВНОЙ РАБОТЫ АНИМАЦИИ:
                    Start-Sleep -Milliseconds 20
                }
                
                if ($Proc.ExitCode -eq 0) {
                    $TimeFinished = (Get-Date).ToString("HH:mm:ss")
                    $Script.LabelRef.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
                    $Script.LabelRef.Text = "✓ Готово ($TimeFinished)"
                    $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
                } else {
                    $Script.LabelRef.Text = "✗ Сбой (Код: $($Proc.ExitCode))"
                    $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
                }
            } catch {
                $Script.LabelRef.Text = "✗ Ошибка"
                $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
            }
        } else {
            $Script.LabelRef.Text = "⚠ Отсутствует"
            $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(249, 226, 175)
        }
        
        # Обновляем ширину заливки прогресс-бара
        $ProgressPercent = ($i + 1) / $ScriptsToRun.Count
        $ProgressFill.Width = [math]::Round(540 * $ProgressPercent)
        
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    # --- ЗАВЕРШАЮЩИЙ ЭТАП ---
    $CurrentActionLabel.Text = "Финальная зачистка временных директорий..."
    [System.Windows.Forms.Application]::DoEvents()

    $ResetPath = Join-Path $ScriptsDir "reset-setup-scripts.ps1"
    if (Test-Path $ResetPath) {
        $ProcReset = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ResetPath`"" -WindowStyle Hidden -PassThru
        while (-not $ProcReset.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 20
        }
    }
    
    $CurrentActionLabel.Text = "Закрытие системы автоматизации через 3 секунды..."
    
    $Timeout = [System.Diagnostics.Stopwatch]::StartNew()
    while ($Timeout.Elapsed.TotalSeconds -lt 3) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 20
    }
    $Form.Close()
})

# Запуск GUI приложения
[System.Windows.Forms.Application]::Run($Form)

    $DragAction = {
        param($sender, $e)
        if ($e.Button -eq 'Left') {
            [Win32.Win32Native]::ReleaseCapture()
            [Win32.Win32Native]::SendMessage($Diag.Handle, 0xA1, 0x2, 0)
        }
    }
    $Diag.Add_MouseDown($DragAction)

    $Border = New-Object System.Windows.Forms.Panel
    $Border.Size = New-Object System.Drawing.Size(496, 296)
    $Border.Location = New-Object System.Drawing.Point(2, 2)
    $Border.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $Border.Add_MouseDown($DragAction)
    $Diag.Controls.Add($Border)

    $Title = New-Object System.Windows.Forms.Label
    $Title.Text = "СИСТЕМА НАСТРОЕНА"
    $Title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold)
    $Title.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
    $Title.Location = New-Object System.Drawing.Point(30, 30)
    $Title.AutoSize = $true
    $Title.Add_MouseDown($DragAction)
    $Border.Controls.Add($Title)

    $Msg = New-Object System.Windows.Forms.Label
    $Msg.Text = "Все операции успешно отработали. Для корректного завершения процесса установки перезагрузите ПК."
    $Msg.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $Msg.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $Msg.Location = New-Object System.Drawing.Point(30, 80)
    $Msg.Size = New-Object System.Drawing.Size(440, 60)
    $Msg.Add_MouseDown($DragAction)
    $Border.Controls.Add($Msg)

    $BtnGit = New-Object System.Windows.Forms.Button
    $BtnGit.Text = "GITHUB РАЗРАБОТЧИКА"
    $BtnGit.Location = New-Object System.Drawing.Point(30, 160)
    $BtnGit.Size = New-Object System.Drawing.Size(440, 45)
    $BtnGit.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
    $BtnGit.ForeColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $BtnGit.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $BtnGit.FlatAppearance.BorderSize = 0
    $BtnGit.Cursor = [System.Windows.Forms.Cursors]::Hand
    $BtnGit.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $BtnGit.Add_Click({ [System.Diagnostics.Process]::Start("https://github.com/alexejnekrasov/powershell-scripts/tree/main") })
    $Border.Controls.Add($BtnGit)

    $BtnOk = New-Object System.Windows.Forms.Button
    $BtnOk.Text = "ВЫХОД"
    $BtnOk.Location = New-Object System.Drawing.Point(30, 220)
    $BtnOk.Size = New-Object System.Drawing.Size(440, 40)
    $BtnOk.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $BtnOk.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $BtnOk.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $BtnOk.FlatAppearance.BorderSize = 0
    $BtnOk.Cursor = [System.Windows.Forms.Cursors]::Hand
    $BtnOk.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $BtnOk.Add_Click({ $Diag.Close() })
    $Border.Controls.Add($BtnOk)

    $Diag.ShowDialog() | Out-Null

# --- 3. ДАННЫЕ ЗАДАЧ ---
$ScriptsToRun = @(
    [PSCustomObject]@{ Name = "clean-and-photo.ps1";        Title = "Оптимизация ОС и просмотр фото";        LogName = "Запуск оптимизации ОС";    LabelRef = $null },
    [PSCustomObject]@{ Name = "install-sys-components.ps1"; Title = "Установка системных компонентов"; LogName = "Настройка компонентов";  LabelRef = $null },
    [PSCustomObject]@{ Name = "apps-install.ps1";           Title = "Установка софта";                 LogName = "Установка ПО";             LabelRef = $null },
    [PSCustomObject]@{ Name = "office-install.ps1";         Title = "Установка и активация Microsoft Office"; LogName = "Установка Office";         LabelRef = $null }
)

# --- 4. ОСНОВНАЯ ФОРМА ---
$Form = New-Object System.Windows.Forms.Form
$Form.Size = New-Object System.Drawing.Size(580, 480)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46) 

$Form.Add_FormClosing({ Show-ExitDialog })

$MainDragAction = {
    param($sender, $e)
    if ($e.Button -eq 'Left') {
        [Win32.Win32Native]::ReleaseCapture()
        [Win32.Win32Native]::SendMessage($Form.Handle, 0xA1, 0x2, 0)
    }
}
$Form.Add_MouseDown($MainDragAction)

$MainPanel = New-Object System.Windows.Forms.Panel
$MainPanel.Size = New-Object System.Drawing.Size(576, 476)
$MainPanel.Location = New-Object System.Drawing.Point(2, 2)
$MainPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
$MainPanel.Add_MouseDown($MainDragAction)
$Form.Controls.Add($MainPanel)

# Главный Заголовок
$MainTitle = New-Object System.Windows.Forms.Label
$MainTitle.Text = "МЕНЕДЖЕР АВТОМАТИЧЕСКОЙ НАСТРОЙКИ"
$MainTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold)
$MainTitle.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$MainTitle.Location = New-Object System.Drawing.Point(20, 20)
$MainTitle.AutoSize = $true
$MainTitle.Add_MouseDown($MainDragAction)
$MainPanel.Controls.Add($MainTitle)

# Синяя стилизованная полоска
$TitleLine = New-Object System.Windows.Forms.Panel
$TitleLine.Location = New-Object System.Drawing.Point(20, 56)
$TitleLine.Size = New-Object System.Drawing.Size(540, 2)
$TitleLine.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$MainPanel.Controls.Add($TitleLine)

# Синяя рамка вокруг крестика закрытия
$CloseBtnFrame = New-Object System.Windows.Forms.Panel
$CloseBtnFrame.Size = New-Object System.Drawing.Size(32, 32)
$CloseBtnFrame.Location = New-Object System.Drawing.Point(528, 18)
$CloseBtnFrame.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$MainPanel.Controls.Add($CloseBtnFrame)

# Крестик
$CloseBtn = New-Object System.Windows.Forms.Label
$CloseBtn.Text = "✕"
$CloseBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
$CloseBtn.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
$CloseBtn.Location = New-Object System.Drawing.Point(2, 2)
$CloseBtn.Size = New-Object System.Drawing.Size(28, 28)
$CloseBtn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$CloseBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$CloseBtn.Add_MouseEnter({ $CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168) })
$CloseBtn.Add_MouseLeave({ $CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200) })
$CloseBtn.Add_Click({ $Form.Close() })
$CloseBtnFrame.Controls.Add($CloseBtn)

# Контейнер задач
$TasksContainer = New-Object System.Windows.Forms.Panel
$TasksContainer.Location = New-Object System.Drawing.Point(20, 75)
$TasksContainer.Size = New-Object System.Drawing.Size(540, 200)
$TasksContainer.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$MainPanel.Controls.Add($TasksContainer)

$YOffset = 20
foreach ($Script in $ScriptsToRun) {
    $TaskLabel = New-Object System.Windows.Forms.Label
    $TaskLabel.Text = $Script.Title
    $TaskLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $TaskLabel.Location = New-Object System.Drawing.Point(20, $YOffset)
    $TaskLabel.Size = New-Object System.Drawing.Size(340, 25)
    $TaskLabel.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $TasksContainer.Controls.Add($TaskLabel)

    $StatusLabel = New-Object System.Windows.Forms.Label
    $StatusLabel.Text = "• Ожидание"
    $StatusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $StatusLabel.Location = New-Object System.Drawing.Point(370, $YOffset)
    $StatusLabel.Size = New-Object System.Drawing.Size(160, 25)
    $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $TasksContainer.Controls.Add($StatusLabel)
    
    $Script.LabelRef = $StatusLabel
    $YOffset += 40
}

# Текущее действие 
$CurrentActionLabel = New-Object System.Windows.Forms.Label
$CurrentActionLabel.Location = New-Object System.Drawing.Point(20, 305)
$CurrentActionLabel.Size = New-Object System.Drawing.Size(540, 25)
$CurrentActionLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
$CurrentActionLabel.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$CurrentActionLabel.Text = "Инициализация подсистем..."
$MainPanel.Controls.Add($CurrentActionLabel)

# =========================================================================
# КАСТОМНЫЙ СПЛОШНОЙ ПРОГРЕСС-БАР
# =========================================================================
# Контейнер (темная подложка)
$ProgressContainer = New-Object System.Windows.Forms.Panel
$ProgressContainer.Location = New-Object System.Drawing.Point(20, 332)
$ProgressContainer.Size = New-Object System.Drawing.Size(540, 20)
$ProgressContainer.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68) 
$MainPanel.Controls.Add($ProgressContainer)

# Заливка (светло-синяя сплошная полоса, стартовая ширина 0)
$ProgressFill = New-Object System.Windows.Forms.Panel
$ProgressFill.Location = New-Object System.Drawing.Point(0, 0)
$ProgressFill.Size = New-Object System.Drawing.Size(0, 20)
$ProgressFill.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250) 
$ProgressContainer.Controls.Add($ProgressFill)
# =========================================================================

# Текст внизу формы
$BottomWarning = New-Object System.Windows.Forms.Label
$BottomWarning.Text = "Пожалуйста, не закрывайте это окно до завершения всех процессов."
$BottomWarning.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$BottomWarning.ForeColor = [System.Drawing.Color]::FromArgb(147, 153, 178)
$BottomWarning.Location = New-Object System.Drawing.Point(0, 420)
$BottomWarning.Size = New-Object System.Drawing.Size(576, 20)
$BottomWarning.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$MainPanel.Controls.Add($BottomWarning)

# --- 5. ФУНКЦИЯ ФОНОВОГО ЛОГА ---
function Add-LogLine ($Prefix, $Message) {
    $Time = (Get-Date).ToString("HH:mm:ss")
    Write-Output "[$Time] [$Prefix] $Message"
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 50
}

# --- 6. ЛОГИКА АВТОМАТИЗАЦИИ ---
$Form.Add_Shown({
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    
    Add-LogLine "CORE" "Запуск планировщика..."
    
    for ($i = 0; $i -lt $ScriptsToRun.Count; $i++) {
        $Script = $ScriptsToRun[$i]
        $ScriptPath = Join-Path $ScriptsDir $Script.Name
        
        $Script.LabelRef.Text = "▶ Выполняется..."
        $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(137, 220, 235)
        $CurrentActionLabel.Text = "Запуск: $($Script.Name)..."
        
        switch ($Script.Name) {
            "clean-and-photo.ps1"        { Add-LogLine "TASK" "Запуск оптимизации ОС" }
            "install-sys-components.ps1" { Add-LogLine "TASK" "Настройка компонентов" }
            "apps-install.ps1"           { Add-LogLine "TASK" "Установка ПО" }
            "office-install.ps1"         { Add-LogLine "TASK" "Установка Office" }
        }

        if (Test-Path $ScriptPath) {
            try {
                $Proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -WindowStyle Hidden -PassThru
                
                while (-not $Proc.HasExited) {
                    [System.Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Milliseconds 100
                }
                
                if ($Proc.ExitCode -eq 0) {
                    $TimeFinished = (Get-Date).ToString("HH:mm:ss")
                    $Script.LabelRef.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
                    $Script.LabelRef.Text = "✓ Готово ($TimeFinished)"
                    $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
                    Add-LogLine " OK " "Модуль завершен."
                } else {
                    $Script.LabelRef.Text = "✗ Сбой (Код: $($Proc.ExitCode))"
                    $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
                    Add-LogLine "FAIL" "Ошибка (Код: $($Proc.ExitCode))"
                }
            } catch {
                $Script.LabelRef.Text = "✗ Ошибка"
                $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
                Add-LogLine "ERR " "Критическая ошибка!"
            }
        } else {
            $Script.LabelRef.Text = "⚠ Отсутствует"
            $Script.LabelRef.ForeColor = [System.Drawing.Color]::FromArgb(249, 226, 175)
            Add-LogLine "WARN" "Файл не найден!"
        }
        
        # Динамическое вычисление и изменение ширины кастомной полосы
        $ProgressPercent = ($i + 1) / $ScriptsToRun.Count
        $ProgressFill.Width = [math]::Round(540 * $ProgressPercent)
        
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    # --- ЗАВЕРШАЮЩИЙ ЭТАП ---
    $CurrentActionLabel.Text = "Финальная зачистка временных директорий..."
    
    Add-LogLine "DONE" "Все процессы завершены."
    Add-LogLine "POST" "Очистка скриптов..."
    [System.Windows.Forms.Application]::DoEvents()

    # Физический вызов скрипта зачистки
    $ResetPath = Join-Path $ScriptsDir "reset-setup-scripts.ps1"
    if (Test-Path $ResetPath) {
        $ProcReset = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ResetPath`"" -WindowStyle Hidden -PassThru
        while (-not $ProcReset.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
    }
    
    $CurrentActionLabel.Text = "Закрытие системы автоматизации через 3 секунды..."
    Add-LogLine "EXIT" "Закрытие (3 сек)..."
    
    $Timeout = [System.Diagnostics.Stopwatch]::StartNew()
    while ($Timeout.Elapsed.TotalSeconds -lt 3) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
    }
    $Form.Close()
})

# Запуск GUI приложения
[System.Windows.Forms.Application]::Run($Form)
