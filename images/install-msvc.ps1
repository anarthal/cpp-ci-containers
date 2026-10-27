#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Installs a single MSVC toolset and makes b2 aware of it. See build-msvc.dockerfile.
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
#   Component:  VS component ID of the toolset, pinning its exact version
#   VcvarsVer:  the version vcvarsall's -vcvars_ver takes, which is also the
#               prefix of the toolset's directory under VC\Tools\MSVC
#   Cl:         the version cl.exe must report
# aka.ms/vs/18/release doesn't exist; VS2026 is published under "stable"
$bootstrapperUrl = 'https://aka.ms/vs/18/stable/vs_buildtools.exe'
$toolsets = @{
    # MSVC v141 - VS2017 C++ build tools. There is no versioned component ID for
    # it, but it needs none: 14.16 is the final, and only, v141 toolset.
    '14.1' = @{ Component = 'Microsoft.VisualStudio.Component.VC.v141.x86.x64';        VcvarsVer = '14.16'; Cl = '19.16' }
    # MSVC v142 - VS2019 C++ build tools (v14.29-16.11)
    '14.2' = @{ Component = 'Microsoft.VisualStudio.Component.VC.14.29.16.11.x86.x64'; VcvarsVer = '14.29'; Cl = '19.29' }
    # MSVC v143 - VS2022 C++ build tools (v14.44-17.14). b2 calls every VS2022
    # toolset 14.3, so there is no "14.4" to install.
    '14.3' = @{ Component = 'Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64'; VcvarsVer = '14.44'; Cl = '19.44' }
    # MSVC v145 - VS2026 C++ build tools (v14.50-18.0). This is the toolset that
    # forces the VS2026 installer: the VS2022 catalog stops at 14.44.
    '14.5' = @{ Component = 'Microsoft.VisualStudio.Component.VC.14.50.18.0.x86.x64'; VcvarsVer = '14.50'; Cl = '19.50' }
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
# vcvarsall.bat (VC.CoreBuildTools), MSBuild itself (Microsoft.Component.MSBuild)
# and the Windows SDK, which holds the Win32 headers and libs and the UCRT.
Write-Host ('Installing {0} ({1})' -f $toolset.Component, $B2Toolset)
Invoke-WebRequest -UseBasicParsing -Uri $bootstrapperUrl -OutFile $bootstrapper
$proc = Start-Process -FilePath $bootstrapper -Wait -PassThru -NoNewWindow -ArgumentList @(
    '--quiet', '--wait', '--norestart', '--nocache',
    '--installPath', $installPath,
    '--add', 'Microsoft.VisualStudio.Component.VC.CoreBuildTools',
    '--add', 'Microsoft.Component.MSBuild',
    '--add', $toolset.Component,
    '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.26100'
)
# 3010 is "installed, but needs a reboot", which doesn't apply to a container
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    throw ('vs_buildtools.exe failed with exit code {0}' -f $proc.ExitCode)
}
Remove-Item $bootstrapper

# The component ID pins the first two components of the toolset version only; the
# third moves with Visual Studio servicing updates, so look the directory up
# instead of hardcoding it.
$msvcDir = Join-Path $installPath 'VC\Tools\MSVC'
$toolsetDir = Get-ChildItem -Directory -Path $msvcDir |
    Where-Object Name -Like ('{0}.*' -f $toolset.VcvarsVer) | Sort-Object Name | Select-Object -Last 1
if (-not $toolsetDir) { throw ('No MSVC toolset matching {0}.* under {1}' -f $toolset.VcvarsVer, $msvcDir) }
Write-Host ('Installed toolset: {0}' -f $toolsetDir.Name)

$cl = Join-Path $toolsetDir.FullName 'bin\Hostx64\x64\cl.exe'
if (-not (Test-Path $cl)) { throw ('cl.exe not found: {0}' -f $cl) }
$vcvarsall = Join-Path $installPath 'VC\Auxiliary\Build\vcvarsall.bat'
if (-not (Test-Path $vcvarsall)) { throw ('vcvarsall.bat not found: {0}' -f $vcvarsall) }

# b2 only auto-detects a toolset that lives in its own generation's Visual Studio
# directory, and it never passes vcvarsall's -vcvars_ver switch, so anything but
# v145 under the VS2026 build tools is invisible to it. Pin the toolset in a
# vcvarsall wrapper and register it in site-config.jam, which b2 reads from
# %SystemRoot% on every run, independently of the user-config.jam that CI jobs
# overwrite. This mirrors what the cppalliance/dronevs images do.
$wrapper = 'C:\vcvars.bat'
('@call "{0}" %* -vcvars_ver={1}' -f $vcvarsall, $toolset.VcvarsVer) | Set-Content -Path $wrapper -Encoding ascii
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
