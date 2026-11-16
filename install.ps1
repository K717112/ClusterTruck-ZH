<#
    ClusterTruck 简体中文补丁 —— 安装脚本
    用法：
        powershell -ExecutionPolicy Bypass -File .\install.ps1
        powershell -ExecutionPolicy Bypass -File .\install.ps1 -GamePath "E:\Steam\steamapps\common\ClusterTruck"
#>
[CmdletBinding()]
param(
    [string]$GamePath = "",
    [string]$PatchDir = "",
    [string]$ReleaseUrl = "https://github.com/K717112/ClusterTruck-ZH/releases/latest/download/ClusterTruck-ZH-patch.zip"
)

$ErrorActionPreference = "Stop"
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$Targets = @(
    @{ Patch = "level0";                     Dest = "Clustertruck_Data\level0" },
    @{ Patch = "level1";                     Dest = "Clustertruck_Data\level1" },
    @{ Patch = "resources.assets";           Dest = "Clustertruck_Data\resources.assets" },
    @{ Patch = "sharedassets0.assets";       Dest = "Clustertruck_Data\sharedassets0.assets" },
    @{ Patch = "Resources\unity default resources"; Dest = "Clustertruck_Data\Resources\unity default resources" },
    @{ Patch = "Managed\Assembly-CSharp.dll";       Dest = "Clustertruck_Data\Managed\Assembly-CSharp.dll" }
)

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
    if ($roots.Count -eq 0 -and (Test-Path "C:\Program Files (x86)\Steam")) {
        $libs += "C:\Program Files (x86)\Steam"
    }
    return ($libs | Select-Object -Unique)
}

function Find-Game {
    if ($GamePath) {
        if (Test-Path (Join-Path $GamePath "Clustertruck.exe")) { return (Resolve-Path $GamePath).Path }
        throw "指定路径里没有 Clustertruck.exe: $GamePath"
    }
    foreach ($lib in (Get-SteamRoots)) {
        $cand = Join-Path $lib "steamapps\common\ClusterTruck"
        if (Test-Path (Join-Path $cand "Clustertruck.exe")) { return (Resolve-Path $cand).Path }
    }
    foreach ($d in @("C:","D:","E:","F:","G:")) {
        $cand = "${d}\Steam\steamapps\common\ClusterTruck"
        if (Test-Path (Join-Path $cand "Clustertruck.exe")) { return (Resolve-Path $cand).Path }
        $cand = "${d}\SteamLibrary\steamapps\common\ClusterTruck"
        if (Test-Path (Join-Path $cand "Clustertruck.exe")) { return (Resolve-Path $cand).Path }
    }
    return $null
}

function Resolve-PatchRoot {
    if ($PatchDir) {
        if (-not (Test-Path (Join-Path $PatchDir "level0"))) { throw "补丁目录无效: $PatchDir" }
        return (Resolve-Path $PatchDir).Path
    }
    $local = Join-Path $script:Root "patch"
    if (Test-Path (Join-Path $local "level0")) { return $local }

    Write-Step "本地没有 patch 目录，从 GitHub Release 下载补丁包…"
    $zip = Join-Path $env:TEMP "ClusterTruck-ZH-patch.zip"
    $out = Join-Path $env:TEMP "ClusterTruck-ZH-patch"
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $ReleaseUrl -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $out -Force
    $inner = Join-Path $out "patch"
    if (Test-Path (Join-Path $inner "level0")) { return $inner }
    if (Test-Path (Join-Path $out "level0")) { return $out }
    throw "解压后找不到补丁文件"
}

# ---------- main ----------
Write-Host ""
Write-Host "  ClusterTruck 简体中文补丁 · 安装" -ForegroundColor White
Write-Host "  ================================" -ForegroundColor DarkGray

$game = Find-Game
if (-not $game) {
    Write-Warn2 "没有自动找到 ClusterTruck。"
    Write-Host "请手动指定游戏根目录（包含 Clustertruck.exe 的那一层），例如："
    Write-Host '  .\install.ps1 -GamePath "E:\Steam\steamapps\common\ClusterTruck"'
    exit 1
}
Write-Ok "游戏目录: $game"

$proc = Get-Process Clustertruck -ErrorAction SilentlyContinue
if ($proc) {
    Write-Warn2 "游戏正在运行，请先完全退出游戏再安装。"
    exit 1
}

$patchRoot = Resolve-PatchRoot
Write-Ok "补丁目录: $patchRoot"

$backup = Join-Path $game "_ZH_backup"
if (-not (Test-Path $backup)) { New-Item -ItemType Directory -Path $backup | Out-Null }

foreach ($t in $Targets) {
    $src = Join-Path $patchRoot $t.Patch
    $dst = Join-Path $game $t.Dest
    if (-not (Test-Path $src)) { Write-Warn2 "补丁缺少文件: $($t.Patch)"; continue }
    if (-not (Test-Path (Split-Path $dst -Parent))) {
        Write-Warn2 "目标目录不存在: $(Split-Path $dst -Parent)"
        continue
    }
    $bak = Join-Path $backup $t.Dest
    if (-not (Test-Path (Split-Path $bak -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $bak -Parent) -Force | Out-Null
    }
    if (-not (Test-Path $bak)) {
        Copy-Item $dst $bak -Force
    }
    Copy-Item $src $dst -Force
    Write-Host ("    - {0}" -f $t.Dest)
}

Write-Host ""
Write-Ok "安装完成，从 Steam 启动游戏即可。"
Write-Host "    还原方法: .\restore.ps1" -ForegroundColor DarkGray
