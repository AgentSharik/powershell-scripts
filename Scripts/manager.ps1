# =========================================================================
# Назначение: GUI с кастомным безрамочным заголовком
# =========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- ГЛАВНАЯ ФОРМА ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = " " # Пустой заголовок
$Form.Size = New-Object System.Drawing.Size(960, 480)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None # УБИРАЕМ РАМКУ
$Form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
# Принудительное включение DoubleBuffered (Безопасный метод)
try {
    $PropertyInfo = [System.Windows.Forms.Control].GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    if ($PropertyInfo) {
        $PropertyInfo.SetValue($Form, $true, $null)
    }
} catch {
    # Если не удалось применить — ничего страшного, просто идем дальше
    Write-Host "Предупреждение: Не удалось включить DoubleBuffered, интерфейс будет работать в обычном режиме." -ForegroundColor Yellow
}

# --- ЛОГИКА ПЕРЕТАСКИВАНИЯ (Драг-энд-дроп окна) ---
$Global:MouseIsDown = $false
$Global:MouseOffset = New-Object System.Drawing.Point

$DragHandler = {
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $Form.Location = New-Object System.Drawing.Point(($Form.Left + $e.X - $Global:MouseOffset.X), ($Form.Top + $e.Y - $Global:MouseOffset.Y))
    }
}

# --- КУСТОМНЫЙ ЗАГОЛОВОК (HEADER) ---
$Header = New-Object System.Windows.Forms.Panel
$Header.Size = New-Object System.Drawing.Size(960, 30)
$Header.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46) # Цвет заголовка
$Header.Add_MouseDown({
    $Global:MouseIsDown = $true
    $Global:MouseOffset = New-Object System.Drawing.Point($_.X, $_.Y)
})
$Header.Add_MouseMove($DragHandler)
$Header.Add_MouseUp({ $Global:MouseIsDown = $false })
$Form.Controls.Add($Header)

# --- КНОПКИ УПРАВЛЕНИЯ (Закрыть/Свернуть) ---
# Кнопка закрытия
$CloseBtn = New-Object System.Windows.Forms.Label
$CloseBtn.Text = "×"
$CloseBtn.Size = New-Object System.Drawing.Size(40, 30)
$CloseBtn.Location = New-Object System.Drawing.Point(920, 0)
$CloseBtn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$CloseBtn.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
$CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
$CloseBtn.Add_MouseEnter({ $CloseBtn.BackColor = [System.Drawing.Color]::FromArgb(243, 139, 168); $CloseBtn.ForeColor = [System.Drawing.Color]::White })
$CloseBtn.Add_MouseLeave({ $CloseBtn.BackColor = [System.Drawing.Color]::Transparent; $CloseBtn.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244) })
$CloseBtn.Add_Click({ $Form.Close() })
$Header.Controls.Add($CloseBtn)

# Кнопка свернуть
$MinBtn = New-Object System.Windows.Forms.Label
$MinBtn.Text = "—"
$MinBtn.Size = New-Object System.Drawing.Size(40, 30)
$MinBtn.Location = New-Object System.Drawing.Point(880, 0)
$MinBtn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$MinBtn.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
$MinBtn.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
$MinBtn.Add_MouseEnter({ $MinBtn.BackColor = [System.Drawing.Color]::FromArgb(88, 91, 112) })
$MinBtn.Add_MouseLeave({ $MinBtn.BackColor = [System.Drawing.Color]::Transparent })
$MinBtn.Add_Click({ $Form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized })
$Header.Controls.Add($MinBtn)

# --- ДАЛЕЕ ВАШ ОСНОВНОЙ ИНТЕРФЕЙС (Размещаем чуть ниже 30px) ---

# Панель для остального контента (сдвинута вниз, чтобы не перекрывать наш заголовок)
$MainContent = New-Object System.Windows.Forms.Panel
$MainContent.Location = New-Object System.Drawing.Point(0, 30)
$MainContent.Size = New-Object System.Drawing.Size(960, 450)
$Form.Controls.Add($MainContent)

# Логотип (Менеджер автоматической настройки)
$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Менеджер автоматической настройки"
$TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold)
$TitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
$TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
$TitleLabel.AutoSize = $true
$MainContent.Controls.Add($TitleLabel)

# ... (Остальной ваш код: Логи, Кнопки, Прогресс-бар)
# Важно: при добавлении новых элементов используйте $MainContent.Controls.Add() вместо $Form.Controls.Add()

# --- ВАША ЛОГИКА ---
# (Вставьте сюда ваш код логики, проходов, логов и кнопки "Готово")

[System.Windows.Forms.Application]::Run($Form)
