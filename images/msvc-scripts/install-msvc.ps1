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
    # The toolset to install (b2 name convention)
    [Parameter(Mandatory = $true)]
    [ValidateSet('14.1', '14.2', '14.3', '14.5')]
    [string] $B2Toolset
)

# Load the utilities
. (Join-Path $PSScriptRoot 'common.ps1')

# We use VS2026 installer for all toolsets, as it allows us to select any MSVC back to 14.1.
# The installer itself can't be version-pinned, but the products it installs are.
# This makes all images use VS2026 though, but that's OK (we care about the compiler).
# vcvarsall is not installed by default in the 14.2 and 14.3 components.
# We use the ComponentGroup components to force its installation. These are small enough.
#
#   Components: VS component IDs to install for this toolset
#   Dir:        matches the toolset's directory under VC\Tools\MSVC
#   Cl:         the version cl.exe must report
$bootstrapperUrl = 'https://aka.ms/vs/18/stable/vs_buildtools.exe'
$toolsets = @{
    # MSVC v141 - would correspond to VS2017.
    # Not versioned, but the published version is no longer updated.
    # Includes vcvarsall.
    '14.1' = @{ Components = @('Microsoft.VisualStudio.Component.VC.v141.x86.x64')
                Dir = '14.16*'; Cl = '19.16' }
    # MSVC v142 - would correspond to VS2019.
    '14.2' = @{ Components = @('Microsoft.VisualStudio.Component.VC.14.29.16.11.x86.x64',
                               'Microsoft.VisualStudio.ComponentGroup.VC.Tools.142.x86.x64')
                Dir = '14.29*'; Cl = '19.29' }
    # MSVC v143 - would correspond to VS2022.
    '14.3' = @{ Components = @('Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64',
                               'Microsoft.VisualStudio.ComponentGroup.VC.Tools.143.x86.x64')
                Dir = '14.44*'; Cl = '19.44' }
    # MSVC v145 - would correspond to VS2026 (latest).
    # The version is not pinned here because we probably want to test the latest MSVC.
    # Also, it brings vcvarsall with it.
    '14.5' = @{ Components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64')
                Dir = '14.5*'; Cl = '19.5' }
}
$toolset = $toolsets[$B2Toolset]

$installPath = 'C:\BuildTools'
$bootstrapper = 'C:\tmp\vs_buildtools.exe'

Write-Host ('Installing {0}: {1}' -f $B2Toolset, ($toolset.Components -join ', '))

# Does not use Get-Verified because the installer version isn't pinned
Invoke-WebRequest -UseBasicParsing -Uri $bootstrapperUrl -OutFile $bootstrapper

$components = @('Microsoft.VisualStudio.Component.VC.CoreBuildTools',
                'Microsoft.Component.MSBuild',
                'Microsoft.VisualStudio.Component.Windows11SDK.26100') + $toolset.Components
Invoke-Installer -Path $bootstrapper -AllowedExitCodes 0, 3010 -Arguments (@(
    '--quiet', '--wait', '--norestart', '--nocache',
    '--installPath', $installPath) + ($components | ForEach-Object { '--add'; $_ }))

# --quiet sends everything to the logs, so individual components can fail without
# the exit code saying so. This is the check the dotnet/framework images use.
# Removing --quiet launches a GUI, which we don't want
$errorLogs = @(Get-ChildItem $env:TEMP -Filter 'dd_setup_*_errors.log' | Where-Object Length -gt 0)
foreach ($log in $errorLogs) {
    Write-Host ('=== {0}' -f $log.FullName)
    Get-Content $log.FullName | Write-Host
}
if ($errorLogs) { throw 'the Visual Studio installer reported errors' }
Remove-Item $bootstrapper
Write-Host ('Free space on C: {0:N1} GB' -f ((Get-PSDrive C).Free / 1GB))

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

# Check that the compiler exists
$cl = Join-Path $toolsetDir.FullName 'bin\Hostx64\x64\cl.exe'
if (-not (Test-Path $cl)) { throw ('cl.exe not found: {0}' -f $cl) }

# Check that vcvarsall exists
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
# v145 under the VS2026 build tools is invisible to it.
# Tell b2 about how to set up the compiler (via a wrapper script)
$wrapper = 'C:\vcvars.bat'
('@call "{0}" %* -vcvars_ver={1}' -f $vcvarsall, $vcvarsVer) | Set-Content -Path $wrapper -Encoding ascii
('using msvc : {0} : "{1}" : <setup>"{2}" ;' -f $B2Toolset, ($cl -replace '\\', '/'), ($wrapper -replace '\\', '/')) |
    Set-Content -Path 'C:\Windows\site-config.jam' -Encoding ascii

Write-Host '=== C:\Windows\site-config.jam ==='
Get-Content 'C:\Windows\site-config.jam' | Write-Host
Write-Host ('=== {0} ===' -f $wrapper)
Get-Content $wrapper | Write-Host

# Smoke test
$clOutput = (& cmd /c "call ""$wrapper"" amd64 > nul 2>&1 && cl 2>&1") -join "`n"
if ($clOutput -notmatch [regex]::Escape('Version ' + $toolset.Cl)) {
    throw ("Expected cl.exe to report version {0}, got:`n{1}" -f $toolset.Cl, $clOutput)
}
Write-Host ('=== cl.exe ===' + "`n" + $clOutput)

# Note nothing installs a VC runtime system-wide, and nothing needs one: every
# bin\Host*\<target> directory of the toolset carries msvcp140.dll, msvcp140_1.dll,
# msvcp140_2.dll and vcruntime140.dll next to cl.exe, in the matching address
# model, and vcvarsall puts that directory on PATH. Anything run from a developer
# environment - b2's tests, and ctest when the CMake jobs are launched the same
# way - finds the runtime there. chocolatey used to install one as a dependency of
# its python package, which is why this was never noticed before.
