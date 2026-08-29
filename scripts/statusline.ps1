#!/usr/bin/env powershell
# Two-line statusline with visual context progress bar (PowerShell port)
#
# Line 1: Model, folder, branch
# Line 2: Progress bar, context %, cost, duration
#
# Context % uses Claude Code's pre-calculated remaining_percentage,
# which accounts for compaction reserves. 100% = compaction fires.
#
# Compatible with PowerShell 5.1+. Git is optional.

# Force UTF-8 output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Helper: return first non-null value
function Coalesce($a, $b) { if ($null -ne $a) { $a } else { $b } }

# Helper: safely access nested property, return default if missing/null
function SafeGet($obj, [string[]]$path, $default = $null) {
    $current = $obj
    foreach ($p in $path) {
        if ($null -eq $current) { return $default }
        $current = $current.$p
    }
    if ($null -ne $current) { $current } else { $default }
}

# Read stdin (Claude Code passes JSON data via stdin)
$stdinData = @($Input) -join "`n"

try {
    $json = $stdinData | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Host "[Unknown] unknown"
    exit 0
}

# Extract fields with fallbacks
$currentDir   = Coalesce (SafeGet $json 'workspace','current_dir') "unknown"
$modelName    = Coalesce (SafeGet $json 'model','display_name') "Unknown"
$cost         = try { [math]::Floor((Coalesce (SafeGet $json 'cost','total_cost_usd') 0) * 100) / 100 } catch { 0 }
$linesAdded   = Coalesce (SafeGet $json 'cost','total_lines_added') 0
$linesRemoved = Coalesce (SafeGet $json 'cost','total_lines_removed') 0
$durationMs   = Coalesce (SafeGet $json 'cost','total_duration_ms') 0

# Context usage calculation
$ctxUsed = $null
try {
    $remaining = SafeGet $json 'context_window','remaining_percentage'
    if ($null -ne $remaining) {
        $ctxUsed = 100 - [math]::Floor($remaining)
    } elseif ((Coalesce (SafeGet $json 'context_window','context_window_size') 0) -gt 0) {
        $usage = SafeGet $json 'context_window','current_usage'
        $totalTokens = (Coalesce (SafeGet $usage 'input_tokens') 0) +
                       (Coalesce (SafeGet $usage 'cache_creation_input_tokens') 0) +
                       (Coalesce (SafeGet $usage 'cache_read_input_tokens') 0)
        $ctxUsed = [math]::Floor($totalTokens * 100 / $json.context_window.context_window_size)
    }
} catch {}

# Cache hit percentage
$cachePct = 0
try {
    $usage = SafeGet $json 'context_window','current_usage'
    $inputTokens = Coalesce (SafeGet $usage 'input_tokens') 0
    $cacheRead   = Coalesce (SafeGet $usage 'cache_read_input_tokens') 0
    if (($inputTokens + $cacheRead) -gt 0) {
        $cachePct = [math]::Floor($cacheRead * 100 / ($inputTokens + $cacheRead))
    }
} catch {}

# ANSI escape sequence helper
$esc = [char]27
function Ansi($code) { "${esc}[${code}m" }

$reset  = Ansi '0'
$dim    = Ansi '2'
$white  = Ansi '37'
$yellow = Ansi '33'
$cyan   = Ansi '36'
$ltblue = Ansi '94'
$ltcyan = Ansi '96'
$green  = Ansi '32'
$red    = Ansi '31'

# Git info (optional - skipped if git is not installed)
$gitBranch = $null
$gitRoot   = $null
$hasGit    = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
if ($hasGit -and (Test-Path $currentDir -ErrorAction SilentlyContinue)) {
    try {
        Push-Location $currentDir
        $gitBranch = git -c core.useBuiltinFSMonitor=false branch --show-current 2>$null
        $gitRoot   = git -c core.useBuiltinFSMonitor=false rev-parse --show-toplevel 2>$null
        Pop-Location
    } catch {
        Pop-Location
    }
}

# Build folder display name
if ($gitRoot) {
    $repoName = Split-Path $gitRoot -Leaf
    if ($currentDir -eq $gitRoot) {
        $folderName = $repoName
    } else {
        $folderName = Split-Path $currentDir -Leaf
    }
} else {
    $folderName = Split-Path $currentDir -Leaf
}

# Generate visual progress bar for context usage
$progressBar = ""
$barWidth = 12
$ctxPct = ""

if ($null -ne $ctxUsed) {
    $filled = [math]::Floor($ctxUsed * $barWidth / 100)
    $empty  = $barWidth - $filled

    if ($ctxUsed -lt 50) {
        $barColor = $green
    } elseif ($ctxUsed -lt 80) {
        $barColor = $yellow
    } else {
        $barColor = $red
    }

    $filledStr = "".PadLeft($filled, '#')
    $emptyStr  = "".PadLeft($empty, '-')

    $progressBar = "${barColor}${filledStr}${dim}${emptyStr}${reset}"
    $ctxPct = "${ctxUsed}%"
}

# Session time (human-readable)
$sessionTime = ""
if ($durationMs -gt 0) {
    $totalSec = [math]::Floor($durationMs / 1000)
    $hours    = [math]::Floor($totalSec / 3600)
    $minutes  = [math]::Floor(($totalSec % 3600) / 60)
    $seconds  = $totalSec % 60
    if ($hours -gt 0) {
        $sessionTime = "${hours}h ${minutes}m"
    } elseif ($minutes -gt 0) {
        $sessionTime = "${minutes}m ${seconds}s"
    } else {
        $sessionTime = "${seconds}s"
    }
}

# Separator
$sep = "${dim}|${reset}"

# Short model name (e.g., "Opus" instead of "Claude 3.5 Opus")
$shortModel = $modelName -replace 'Claude [0-9.]+ ', '' -replace '^Claude ', ''

# LINE 1: [Model] folder | branch
$line1 = "${white}[${shortModel}]${reset}"
$line1 += " ${ltblue}${folderName}${reset}"
if ($gitBranch) {
    $line1 += " ${sep} ${ltcyan}${gitBranch}${reset}"
}

# LINE 2: Progress bar | Context % | cost | duration | cache
$line2 = ""
if ($progressBar) {
    $line2 = $progressBar
}
if ($ctxPct) {
    if ($line2) {
        $line2 += " ${white}${ctxPct}${reset}"
    } else {
        $line2 = "${white}${ctxPct}${reset}"
    }
}
if ($line2) {
    $line2 += " ${sep} ${yellow}`$${cost}${reset}"
} else {
    $line2 = "${yellow}`$${cost}${reset}"
}
if ($sessionTime) {
    $line2 += " ${sep} ${cyan}${sessionTime}${reset}"
}
if ($cachePct -gt 0) {
    $line2 += " ${dim}cache:${cachePct}%${reset}"
}

Write-Host "${line1}`n`n${line2}" -NoNewline
