# =========================================================================
# Имя файла: Main_Setup_GUI_Dispatcher.ps1
# Назначение: Модернизированный GUI Диспетчер с агрессивным чтением логов
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# --- СКРЫВАЕМ КОНСОЛЬ ---
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

$UserProfile = $env:USERPROFILE
$LogDir = Join-Path $UserProfile "Documents"

$ScriptsToRun = @(
    @{ Name = "clean-and-photo.ps1";        Title = "Оптимизация ОС и просмотр фото";       Status = "Ожидание" },
    @{ Name = "install-sys-components.ps1"; Title = "Установка системных компонентов"; Status = "Ожидание" },
    @{ Name = "apps-install.ps1";           Title = "Установка софта";                 Status = "Ожидание" },
    @{ Name = "office-install.ps1";         Title = "Установка и активация Microsoft Office"; Status = "Ожидание" }
)

# --- GUI ИНИЦИАЛИЗАЦИЯ ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = " Системная автоматизация Windows"
$Form.Size = New-Object System.Drawing.Size(1040, 480)
$Form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
$Form.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

# [Контейнеры GUI и Label-ы пропускаю для краткости, они идентичны вашим]
$LogTextBox = New-Object System.Windows.Forms.RichTextBox
$LogTextBox.Location = New-Object System.Drawing.Point(595, 95) # Подправил координаты для вашего окна
$LogTextBox.Size = New-Object System.Drawing.Size(410, 320)
$LogTextBox.BackColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
$LogTextBox.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
$LogTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$LogTextBox.ReadOnly = $true
$Form.Controls.Add($LogTextBox)

function Add-LogLine ($Prefix, $Message, $ColorRGB = @(166, 173, 200)) {
    $Time = (Get-Date).ToString("HH:mm:ss")
    $LogTextBox.SelectionStart = $LogTextBox.TextLength
    $LogTextBox.SelectionColor = [System.Drawing.Color]::FromArgb(108, 112, 134)
    $LogTextBox.AppendText("[$Time] ")
    $LogTextBox.SelectionColor = [System.Drawing.Color]::FromArgb($ColorRGB[0], $ColorRGB[1], $ColorRGB[2])
    $LogTextBox.AppendText("[$Prefix] ")
    $LogTextBox.SelectionColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $LogTextBox.AppendText("$Message`r`n")
    $LogTextBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# --- ЛОГИКА ВЫПОЛНЕНИЯ ---
$Form.Add_Shown({
    $ScriptsDir = "C:\Windows\Setup\Scripts"
    
    foreach ($Script in $ScriptsToRun) {
        $ScriptPath = Join-Path $ScriptsDir $Script.Name
        Add-LogLine "CORE" "Запуск: $($Script.Name)" @(137, 220, 235)
        
        if (Test-Path $ScriptPath) {
            $StartTime = (Get-Date).AddSeconds(-5)
            $Proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -WindowStyle Hidden -PassThru
            
            $FileStream = $null
            $StreamReader = $null
            $ChildLogPath = $null

            # Цикл агрессивного чтения
            while (-not $Proc.HasExited) {
                [System.Windows.Forms.Application]::DoEvents()
                
                # 1. Поиск лога
                if ($null -eq $ChildLogPath) {
                    $LatestLog = Get-ChildItem -Path $LogDir -File | 
                                 Where-Object { ($_.Extension -eq '.log' -or $_.Extension -eq '.txt') -and ($_.LastWriteTime -ge $StartTime) } | 
                                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    if ($LatestLog) { $ChildLogPath = $LatestLog.FullName }
                }

                # 2. Подключение
                if ($null -ne $ChildLogPath -and (Test-Path $ChildLogPath) -and ($null -eq $FileStream)) {
                    try {
                        $FileStream = New-Object System.IO.FileStream($ChildLogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                        $FileStream.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null
                        $StreamReader = New-Object System.IO.StreamReader($FileStream, [System.Text.Encoding]::UTF8)
                    } catch { }
                }

                # 3. Чтение и парсинг
                if ($null -ne $StreamReader) {
                    while ($StreamReader.Peek() -ne -1) {
                        $Line = $StreamReader.ReadLine().Trim()
                        if ($Line -ne "" -and $Line -notmatch "^\*+$") {
                             # Определение цвета на основе ключевых слов
                             $Color = @(166, 173, 200)
                             $Prefix = "INFO"
                             if ($Line -match ">>>") { $Prefix = "STEP"; $Color = @(137, 220, 235) }
                             elseif ($Line -match "(?i)успешно") { $Prefix = " OK "; $Color = @(166, 227, 161) }
                             elseif ($Line -match "(?i)ошибка|сбой|WARNING|ERROR") { $Prefix = "FAIL"; $Color = @(243, 139, 168) }
                             
                             Add-LogLine $Prefix $Line $Color
                        }
                    }
                }
                Start-Sleep -Milliseconds 50
            }

            # Финальный проход после завершения процесса
            if ($null -ne $StreamReader) {
                while ($StreamReader.Peek() -ne -1) {
                     $Line = $StreamReader.ReadLine().Trim()
                     if ($Line -ne "") { Add-LogLine "INFO" $Line @(166, 173, 200) }
                }
                $StreamReader.Close(); $StreamReader.Dispose()
            }
            if ($null -ne $FileStream) { $FileStream.Close(); $FileStream.Dispose() }
        }
    }
    Add-LogLine "DONE" "Все процессы завершены." @(166, 227, 161)
})

[System.Windows.Forms.Application]::Run($Form)
