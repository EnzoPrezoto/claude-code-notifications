# Claude Code Notifications

Native Windows toast notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — get notified when Claude finishes a task, encounters an error, or needs your input.

![Windows 10+](https://img.shields.io/badge/Windows-10%2B-0078D6?logo=windows)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell)
![License](https://img.shields.io/badge/license-MIT-green)

## What it does

Uses Claude Code's **hooks system** to automatically trigger Windows toast notifications (with sound) on key events:

| Event | When it fires | Notification |
|-------|--------------|--------------|
| **Stop** | Claude finishes and waits for your input | "Ready for your input" |
| **PostToolUse** | A tool errors or exits non-zero | Shows error details |
| **Notification** | Claude sends a status update | Shows the message |

No polling. No background processes. Just hooks.

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/EnzoPrezoto/claude-code-notifications.git
```

### 2. Configure Claude Code hooks

Add the following to your `~/.claude/settings.json` (update the path to where you cloned the repo):

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "command": "powershell -ExecutionPolicy Bypass -File \"C:/path/to/claude-code-notifications/claude-notify.ps1\" -Event stop"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "command": "powershell -ExecutionPolicy Bypass -File \"C:/path/to/claude-code-notifications/claude-notify.ps1\" -Event post_tool_use"
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "command": "powershell -ExecutionPolicy Bypass -File \"C:/path/to/claude-code-notifications/claude-notify.ps1\" -Event notification"
      }
    ]
  }
}
```

### 3. Test it

```powershell
.\claude-notify.ps1 -Title "Test" -Message "It works!" -Type "info"
```

You should see a Windows toast notification with sound.

## Manual usage

```powershell
# Basic notification
.\claude-notify.ps1 -Message "Hello from Claude"

# Custom title and type
.\claude-notify.ps1 -Title "Build Done" -Message "All tests passed" -Type "success"

# Error notification
.\claude-notify.ps1 -Title "Failure" -Message "Something broke" -Type "error"
```

### Parameters

| Parameter | Default | Values | Description |
|-----------|---------|--------|-------------|
| `-Event` | `direct` | `direct`, `stop`, `post_tool_use`, `notification` | Hook event type (auto-set by hooks) |
| `-Title` | `Claude Code` | any string | Notification title |
| `-Message` | varies | any string | Notification body |
| `-Type` | `info` | `info`, `success`, `error`, `warning` | Notification severity |

## How it works

1. Claude Code fires a **hook event** (Stop, PostToolUse, or Notification)
2. The hook runs `claude-notify.ps1` with the event type
3. The script reads event context from stdin (JSON piped by Claude Code)
4. For `post_tool_use`, it only notifies if there's an actual error (no spam)
5. Sends a **Windows toast notification** via the WinRT API
6. Falls back to a **balloon tip** if toast fails

## Requirements

- **Windows 10+** (build 10240 or later)
- **PowerShell 5.1+** (pre-installed on Windows 10+)
- **Claude Code CLI**

## Contributing

PRs welcome. If you want to add support for macOS/Linux, that would be great.

## Authors

- **Enzo Prezoto** — [GitHub](https://github.com/EnzoPrezoto)
- **Claude (Opus 4.6)** — AI pair programmer by [Anthropic](https://anthropic.com)

## License

MIT
