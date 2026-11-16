<#
    ClusterTruck 简体中文补丁 —— 还原脚本
    用法：
        powershell -ExecutionPolicy Bypass -File .\restore.ps1
        powershell -ExecutionPolicy Bypass -File .\restore.ps1 -GamePath "E:\Steam\steamapps\common\ClusterTruck"
#>
[CmdletBinding()]
param(
    [string]$GamePath = ""
)

$ErrorActionPreference = "Stop"
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step($msg) { Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "[!] $msg" -ForegroundColor Yellow }

function Get-SteamRoots {
    $roots = @()
    $keys = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam"
    )
    foreach ($k in $keys) {
        try {
            $p = Get-ItemProperty -Path $k -ErrorAction Stop
            foreach ($name in @("SteamPath", "InstallPath")) {
                if ($p.$name) { $roots += ($p.$name -replace "/", "\") }
            }
        } catch { }
    }
    $roots = $roots | Select-Object -Unique
    $libs = @()
    foreach ($r in $roots) {
        if (Test-Path $r) { $libs += $r }
        $vdf = Join-Path $r "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            Select-String -Path $vdf -Pattern '"path"\s+"(.+?)"' -AllMatches |
                ForEach-Object { $_.Matches } |
                ForEach-Object { $libs += ($_.Groups[1].Value -replace "\\\\", "\") }
        }
    }
    return ($libs | Select-Object -Unique)
}

function Find-Game {
    if ($GamePath) { return (Resolve-Path $GamePath).Path }
    foreach ($lib in (Get-SteamRoots)) {
        $cand = Join-Path $lib "steamapps\common\ClusterTruck"
        if (Test-Path (Join-Path $cand "_ZH_backup")) { return (Resolve-Path $cand).Path }
    }
    foreach ($d in @("C:","D:","E:","F:","G:")) {
        foreach ($sub in @("Steam","SteamLibrary")) {
            $cand = "${d}\${sub}\steamapps\common\ClusterTruck"
            if (Test-Path (Join-Path $cand "_ZH_backup")) { return (Resolve-Path $cand).Path }
        }
    }
    return $null
}

Write-Host ""
Write-Host "  ClusterTruck 简体中文补丁 · 还原" -ForegroundColor White
Write-Host "  ================================" -ForegroundColor DarkGray

$game = Find-Game
if (-not $game) {
    Write-Warn2 "没有找到带 _ZH_backup 的游戏目录，请用 -GamePath 指定。"
    exit 1
}
Write-Ok "游戏目录: $game"

$backup = Join-Path $game "_ZH_backup"
if (-not (Test-Path $backup)) {
    Write-Warn2 "备份目录不存在: $backup"
    exit 1
}

$files = Get-ChildItem -Path $backup -Recurse -File
foreach ($f in $files) {
    $rel = $f.FullName.Substring($backup.Length).TrimStart("\")
    $dst = Join-Path $game $rel
    Copy-Item $f.FullName $dst -Force
    Write-Host ("    - {0}" -f $rel)
}

Write-Host ""
Write-Ok "已还原为原版文件（备份目录 $backup 保留，可自行删除）。"
