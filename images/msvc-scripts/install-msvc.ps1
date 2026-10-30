#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Installs a single MSVC toolset and makes b2 aware of it. See ../build-msvc.dockerfile.
# Inspired by https://github.com/cppalliance/drone-ci/tree/master/dockers/dronevs2026/windows2025

[CmdletBinding()]
param (
    # The toolset to install, named as b2 names it (b2 toolset=msvc-<version>)
    [Parameter(Mandatory = $true)]
    [ValidateSet('14.1', '14.2', '14.3', '14.5')]
    [string] $B2Toolset
)

$ErrorActionPreference = 'Stop'

# The VS2026 installer offers every toolset back to v141, so one bootstrapper
# covers all the images. Each toolset is pinned by its component ID, so which
# build of the installer runs doesn't affect the compiler we get.
# Note this makes every image a Visual Studio "18" instance: CMake builds need
# the "Visual Studio 18 2026" generator.
#   Components: VS component IDs to install for this toolset
#   Dir:        matches the toolset's directory under VC\Tools\MSVC
#   Cl:         the version cl.exe must report
#
# vcvarsall.bat ships in the package Microsoft.VisualCpp.Tools.Core.x86, which the
# versioned toolset components don't pull in (v141 is the one exception). The
# ComponentGroup.VC.Tools.14x groups do, and they're built from the same packages
# the matching toolset already installs, so they cost ~4MB.
# aka.ms/vs/18/release doesn't exist; VS2026 is published under "stable"
$bootstrapperUrl = 'https://aka.ms/vs/18/stable/vs_buildtools.exe'
$toolsets = @{
    # MSVC v141 - VS2017 C++ build tools. No versioned component ID exists, and it
    # needs none: 14.16 is the final, and only, v141 toolset. It's also the only
    # toolset component that brings vcvarsall.bat along.
    '14.1' = @{ Components = @('Microsoft.VisualStudio.Component.VC.v141.x86.x64')
                Dir = '14.16*'; Cl = '19.16' }
    # MSVC v142 - VS2019 C++ build tools (v14.29-16.11)
    '14.2' = @{ Components = @('Microsoft.VisualStudio.Component.VC.14.29.16.11.x86.x64',
                               'Microsoft.VisualStudio.ComponentGroup.VC.Tools.142.x86.x64')
                Dir = '14.29*'; Cl = '19.29' }
    # MSVC v143 - VS2022 C++ build tools (v14.44-17.14). b2 calls every VS2022
    # toolset 14.3, so there is no "14.4" to install.
    '14.3' = @{ Components = @('Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64',
                               'Microsoft.VisualStudio.ComponentGroup.VC.Tools.143.x86.x64')
                Dir = '14.44*'; Cl = '19.44' }
    # MSVC v145 - VS2026. This one takes the current toolset rather than a pinned
    # one: there is no ComponentGroup.VC.Tools.145 to pair with the versioned
    # component, and VC.Tools.x86.x64 brings vcvarsall.bat while being ~0.9GB
    # smaller, since the versioned components carry their own copy of everything
    # and then pull the current tools anyway. The version floats with VS, which is
    # what you want from the image that tracks the newest MSVC.
    '14.5' = @{ Components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64')
                Dir = '14.5*'; Cl = '19.5' }
}
$toolset = $toolsets[$B2Toolset]

$installPath = 'C:\BuildTools'
$bootstrapper = 'C:\tmp\vs_buildtools.exe'

# The components are listed individually rather than through
# Microsoft.VisualStudio.Workload.VCTools: that workload *requires*
# ComponentGroup.NativeDesktop.Core, which is 5.1GB of IDE machinery unreachable
# from a build tools container (3.2GB of it is WebView2, the rest Team Explorer,
# VS Identity, two .NET runtimes, the VS terminal and Roslyn ServiceHub).
# Each toolset component is self-contained: it carries its own CRT, compilers,
# PGO, DIA SDK, MSBuild targets and VC redistributables. What it doesn't carry is
# the VC core and VsDevCmd (VC.CoreBuildTools), MSBuild itself
# (Microsoft.Component.MSBuild) and the Windows SDK, which holds the Win32 headers
# and libs and the UCRT.
Write-Host ('Installing {0}: {1}' -f $B2Toolset, ($toolset.Components -join ', '))
Invoke-WebRequest -UseBasicParsing -Uri $bootstrapperUrl -OutFile $bootstrapper
# --add silently ignores anything that isn't a workload, component or component
# group - no error, no log line - so every ID here has to be one of those.
$components = @('Microsoft.VisualStudio.Component.VC.CoreBuildTools',
                'Microsoft.Component.MSBuild',
                'Microsoft.VisualStudio.Component.Windows11SDK.26100') + $toolset.Components
$proc = Start-Process -FilePath $bootstrapper -Wait -PassThru -NoNewWindow -ArgumentList (@(
    '--quiet', '--wait', '--norestart', '--nocache',
    '--installPath', $installPath) + ($components | ForEach-Object { '--add'; $_ }))
Write-Host ('vs_buildtools.exe exited with {0}' -f $proc.ExitCode)
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    throw ('vs_buildtools.exe failed with exit code {0}' -f $proc.ExitCode)
}
# --quiet sends everything to the logs, so individual components can fail without
# the exit code saying so. This is the check the dotnet/framework images use.
$errorLogs = @(Get-ChildItem $env:TEMP -Filter 'dd_setup_*_errors.log' | Where-Object Length -gt 0)
foreach ($log in $errorLogs) {
    Write-Host ('=== {0}' -f $log.FullName)
    Get-Content $log.FullName | Write-Host
}
if ($errorLogs) { throw 'the Visual Studio installer reported errors' }
Remove-Item $bootstrapper
Write-Host ('Free space on C: {0:N1} GB' -f ((Get-PSDrive C).Free / 1GB))

# TEMPORARY: what the installer actually recorded and laid down
Write-Host '=== installed packages ==='
Get-ChildItem 'C:\ProgramData\Microsoft\VisualStudio\Packages\_Instances' -Directory -ErrorAction SilentlyContinue |
    ForEach-Object {
        $state = Join-Path $_.FullName 'state.json'
        if (Test-Path $state) {
            (Get-Content $state -Raw | ConvertFrom-Json).packages |
                ForEach-Object { '{0} {1}' -f $_.id, $_.version } | Sort-Object | Write-Host
        }
    }
Write-Host '=== installed files ==='
$installed = @(Get-ChildItem $installPath -Recurse -File -ErrorAction SilentlyContinue)
$installed | ForEach-Object { $_.FullName } | Write-Host
Write-Host ('{0} files, {1:N2} GB under {2}' -f
    $installed.Count, (($installed | Measure-Object Length -Sum).Sum / 1GB), $installPath)

# The component ID pins the first two components of the toolset version only; the
# third moves with Visual Studio servicing updates, so look the directory up
# instead of hardcoding it.
$msvcDir = Join-Path $installPath 'VC\Tools\MSVC'
$toolsetDir = Get-ChildItem -Directory -Path $msvcDir |
    Where-Object Name -Like $toolset.Dir | Sort-Object Name | Select-Object -Last 1
if (-not $toolsetDir) { throw ('No MSVC toolset matching {0} under {1}' -f $toolset.Dir, $msvcDir) }
Write-Host ('Installed toolset: {0}' -f $toolsetDir.Name)
# -vcvars_ver takes the two-component version, which only the directory knows: the
# component ID doesn't carry it at all for 14.5, and only partly for the others.
$vcvarsVer = ($toolsetDir.Name -split '\.')[0, 1] -join '.'

$cl = Join-Path $toolsetDir.FullName 'bin\Hostx64\x64\cl.exe'
if (-not (Test-Path $cl)) { throw ('cl.exe not found: {0}' -f $cl) }

$vcvarsall = Join-Path $installPath 'VC\Auxiliary\Build\vcvarsall.bat'
if (-not (Test-Path $vcvarsall)) {
    Get-ChildItem (Join-Path $installPath 'VC') -Depth 2 -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName | Write-Host
    throw ('vcvarsall.bat not found: {0}' -f $vcvarsall)
}

# Name the toolset this image actually has: the default.txt the installer leaves
# behind names the one it considers current, which isn't installed here. MSBuild
# and CMake read it to pick a compiler.
Set-Content -Path (Join-Path $installPath 'VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt') `
    -Value $toolsetDir.Name -Encoding ascii

# b2 only auto-detects a toolset that lives in its own generation's Visual Studio
# directory, and it never passes vcvarsall's -vcvars_ver switch, so anything but
# v145 under the VS2026 build tools is invisible to it. Pin the toolset in a
# vcvarsall wrapper and register it in site-config.jam, which b2 reads from
# %SystemRoot% on every run, independently of the user-config.jam that CI jobs
# overwrite. This mirrors what the cppalliance/dronevs images do.
$wrapper = 'C:\vcvars.bat'
('@call "{0}" %* -vcvars_ver={1}' -f $vcvarsall, $vcvarsVer) | Set-Content -Path $wrapper -Encoding ascii
('using msvc : {0} : "{1}" : <setup>"{2}" ;' -f $B2Toolset, ($cl -replace '\\', '/'), ($wrapper -replace '\\', '/')) |
    Set-Content -Path 'C:\Windows\site-config.jam' -Encoding ascii

Write-Host '=== C:\Windows\site-config.jam ==='
Get-Content 'C:\Windows\site-config.jam' | Write-Host
Write-Host ('=== {0} ===' -f $wrapper)
Get-Content $wrapper | Write-Host

# Check that the wrapper really selects the toolset we think it does
$clOutput = (& cmd /c "call ""$wrapper"" amd64 > nul 2>&1 && cl 2>&1") -join "`n"
if ($clOutput -notmatch [regex]::Escape('Version ' + $toolset.Cl)) {
    throw ("Expected cl.exe to report version {0}, got:`n{1}" -f $toolset.Cl, $clOutput)
}
Write-Host ('=== cl.exe ===' + "`n" + $clOutput)
