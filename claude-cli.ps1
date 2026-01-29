# Claude CLI PowerShell Plugin

# Global variables
$global:__CLAUDE_CLI_SESSION_FILE = "$env:TEMP\.claude-session-$PID.txt"
$global:__CLAUDE_CLI_ORIGIN_DIR_FILE = "$env:TEMP\.claude-origin-dir-$PID.txt"

# Function to send command to Claude
function Invoke-ClaudeCLI {
    param(
        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [string[]]$Command
    )
    
    $fullCommand = $Command -join ' '
    
    if ([string]::IsNullOrWhiteSpace($fullCommand)) {
        return
    }
    
    # Session management
    $sessionId = $null
    $sessionStarted = $false
    
    if (Test-Path $global:__CLAUDE_CLI_SESSION_FILE) {
        try {
            $sessionInfo = Get-Content $global:__CLAUDE_CLI_SESSION_FILE -Raw | ConvertFrom-StringData
            $sessionId = $sessionInfo.session_id
            $sessionStarted = [bool]::Parse($sessionInfo.session_started)
        } catch {
            $sessionId = $null
            $sessionStarted = $false
        }
    }
    
    if (-not $sessionId) {
        $sessionId = [guid]::NewGuid().ToString()
        $sessionStarted = $false
    }
    
    # Directory management
    $originDir = $null
    if (-not $sessionStarted) {
        $originDir = Get-Location | Select-Object -ExpandProperty Path
        Set-Content -Path $global:__CLAUDE_CLI_ORIGIN_DIR_FILE -Value $originDir -NoNewline
    } else {
        if (Test-Path $global:__CLAUDE_CLI_ORIGIN_DIR_FILE) {
            $originDir = Get-Content $global:__CLAUDE_CLI_ORIGIN_DIR_FILE -Raw
        } else {
            $originDir = Get-Location | Select-Object -ExpandProperty Path
        }
    }
    
    $currentDir = Get-Location | Select-Object -ExpandProperty Path
    
    if ($currentDir -ne $originDir) {
        $fullCommand = "$fullCommand (Current working directory: $currentDir)"
    }
    
    $needRestore = $false
    if ($currentDir -ne $originDir) {
        Push-Location $originDir -ErrorAction SilentlyContinue
        $needRestore = $true
    }
    
    try {
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
            Write-Host "Error: claude command not found" -ForegroundColor Red
            return
        }
        
        if (-not $sessionStarted) {
            & claude --dangerously-skip-permissions --session-id $sessionId -p $fullCommand
            
            @"
session_id=$sessionId
session_started=True
"@ | Set-Content -Path $global:__CLAUDE_CLI_SESSION_FILE
        } else {
            & claude --dangerously-skip-permissions --resume $sessionId -p $fullCommand
        }
    } finally {
        if ($needRestore) {
            Pop-Location
        }
    }
}

# Create alias for easy use
Set-Alias -Name AI -Value Invoke-ClaudeCLI

# Bind Ctrl-X to toggle "AI " prefix (simple text manipulation only)
Set-PSReadLineKeyHandler -Chord 'Ctrl+x' -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    
    if ($line -match '^AI\s') {
        # Remove "AI " prefix (3 characters: "AI ")
        $newLine = $line.Substring(3)
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $newLine)
    } else {
        # Add "AI " prefix
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, "AI $line")
    }
}

# Cleanup function
$global:__CLAUDE_CLI_CLEANUP = {
    Remove-Item -Path $global:__CLAUDE_CLI_SESSION_FILE -ErrorAction SilentlyContinue
    Remove-Item -Path $global:__CLAUDE_CLI_ORIGIN_DIR_FILE -ErrorAction SilentlyContinue
}

# Register exit event
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $global:__CLAUDE_CLI_CLEANUP | Out-Null

Write-Host "Claude CLI PowerShell plugin loaded!" -ForegroundColor Green
Write-Host "  Usage: AI <your question>" -ForegroundColor Gray
Write-Host "  Tip: Press Ctrl-X to toggle 'AI ' prefix" -ForegroundColor Gray
