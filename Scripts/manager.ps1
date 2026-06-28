Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- GUI ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Автоматическая настройка"
$Form.Size = New-Object System.Drawing.Size(600, 300)
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.TopMost = $true 

# Простой шрифт (Только Имя и Размер. Никаких стилей!)
$MyFont = New-Object System.Drawing.Font("Arial", 10)

$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Идет установка, пожалуйста, подождите..."
$Label.Location = New-Object System.Drawing.Point(20, 20)
$Label.Size = New-Object System.Drawing.Size(550, 30)
$Label.Font = $MyFont
$Form.Controls.Add($Label)

$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(20, 60)
$ProgressBar.Size = New-Object System.Drawing.Size(550, 30)
$ProgressBar.Style = 1 # Marquee/Continuous
$ProgressBar.MarqueeAnimationSpeed = 30
$ProgressBar.Value = 50
$Form.Controls.Add($ProgressBar)

# Запуск
$Form.Add_Shown({
    # Здесь просто имитируем работу, чтобы GUI не завис
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        # Логика запуска скриптов по очереди
        $timer.Stop()
        $Form.Close()
        # ВАЖНО: Сам запуск скриптов лучше делать отдельно, 
        # чтобы они не вешали основной поток GUI
    })
    $timer.Start()
})

[System.Windows.Forms.Application]::Run($Form)
