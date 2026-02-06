# claude-notify.ps1 - Windows notification system for Claude Code
# Usage:
#   Direct:  .\claude-notify.ps1 -Title "Title" -Message "Hello"
#   Hook:    <stdin JSON> | .\claude-notify.ps1 -Event stop

param(
    [ValidateSet("direct", "stop", "post_tool_use", "notification")]
    [string]$Event = "direct",
    [string]$Title = "Claude Code",
    [string]$Message = "",
    [ValidateSet("info", "success", "error", "warning")]
    [string]$Type = "info"
)

# --- Read stdin for hook events ---
$hookData = $null
if ($Event -ne "direct") {
    try {
        $raw = @($input) -join "`n"
        if ($raw.Trim()) {
            $hookData = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
    } catch {}
}

# --- Determine notification content based on event type ---
switch ($Event) {
    "stop" {
        $Title = "Claude Code"
        if (-not $Message) { $Message = "Ready for your input" }
        $Type = "success"
    }
    "post_tool_use" {
        $hasError = $false
        if ($hookData) {
            # Check for error in tool result
            if ($hookData.error) {
                $hasError = $true
                $toolName = if ($hookData.tool_name) { $hookData.tool_name } else { "Tool" }
                $errText = if ($hookData.error -is [string]) { $hookData.error } else { ($hookData.error | Out-String).Trim() }
                if ($errText.Length -gt 200) { $errText = $errText.Substring(0, 200) + "..." }
                $Message = "$toolName error: $errText"
                $Type = "error"
                $Title = "Claude Code - Error"
            }
            # Also check for non-zero exit codes in Bash results
            if ($hookData.tool_result -and $hookData.tool_result.exit_code -and $hookData.tool_result.exit_code -ne 0) {
                $hasError = $true
                $toolName = if ($hookData.tool_name) { $hookData.tool_name } else { "Tool" }
                $Message = "$toolName exited with code $($hookData.tool_result.exit_code)"
                $Type = "warning"
                $Title = "Claude Code - Warning"
            }
        }
        if (-not $hasError) { exit 0 }
    }
    "notification" {
        if ($hookData -and $hookData.message) {
            $Message = $hookData.message
        }
        if (-not $Message) { $Message = "Claude Code notification" }
        $Title = "Claude Code"
    }
    "direct" {
        if (-not $Message) { $Message = "Notification from Claude Code" }
    }
}

# --- Send Toast Notification (Windows 10+) ---
function Send-ToastNotification {
    param([string]$NTitle, [string]$NMessage)

    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

        $safeTitle = [System.Security.SecurityElement]::Escape($NTitle)
        $safeMsg = [System.Security.SecurityElement]::Escape($NMessage)

        $toastXml = @"
<toast duration="short">
    <visual>
        <binding template="ToastGeneric">
            <text>$safeTitle</text>
            <text>$safeMsg</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@

        $xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
        $xml.LoadXml($toastXml)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)

        # Use PowerShell's registered AppId for reliable delivery
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
        return $true
    }
    catch {
        return $false
    }
}

# --- Fallback: Balloon Tip Notification ---
function Send-BalloonNotification {
    param([string]$NTitle, [string]$NMessage, [string]$NType)

    try {
        Add-Type -AssemblyName System.Windows.Forms
        $tipIcon = switch ($NType) {
            "error"   { [System.Windows.Forms.ToolTipIcon]::Error }
            "warning" { [System.Windows.Forms.ToolTipIcon]::Warning }
            default   { [System.Windows.Forms.ToolTipIcon]::Info }
        }

        $balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.Icon = [System.Drawing.SystemIcons]::Information
        $balloon.BalloonTipIcon = $tipIcon
        $balloon.BalloonTipTitle = $NTitle
        $balloon.BalloonTipText = $NMessage
        $balloon.Visible = $true
        $balloon.ShowBalloonTip(5000)
        Start-Sleep -Milliseconds 5500
        $balloon.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

# --- Send notification: try toast first, fallback to balloon ---
$sent = Send-ToastNotification -NTitle $Title -NMessage $Message
if (-not $sent) {
    Send-BalloonNotification -NTitle $Title -NMessage $Message -NType $Type | Out-Null
}
