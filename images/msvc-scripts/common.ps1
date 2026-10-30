#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Helpers shared by the install scripts in this directory

$ErrorActionPreference = 'Stop'

# Downloads a file, and refuses to go on unless it's the one we expected.
function Get-Verified {
    param (
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [string] $Sha256,
        [Parameter(Mandatory)] [string] $OutFile
    )
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $OutFile
    $actual = (Get-FileHash $OutFile -Algorithm SHA256).Hash
    if ($actual -ne $Sha256) { throw "$Url checksum mismatch: expected $Sha256, got $actual" }
}

# Downloads a verified archive, expands it, and throws the archive away.
function Expand-Verified {
    param (
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [string] $Sha256,
        [Parameter(Mandatory)] [string] $DestinationPath
    )
    $archive = Join-Path 'C:\tmp' (Split-Path -Leaf ([uri] $Url).AbsolutePath)
    Get-Verified -Url $Url -Sha256 $Sha256 -OutFile $archive
    Expand-Archive -Path $archive -DestinationPath $DestinationPath
    Remove-Item -Force $archive
}

# Prepends a directory to the machine PATH and to this process's
function Add-MachinePath {
    param ([Parameter(Mandatory)] [string] $Dir)
    $path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::SetEnvironmentVariable('Path', "$Dir;$path", 'Machine')
    $env:Path = "$Dir;$env:Path"
}

# Runs a native command and throws if it fails. PowerShell won't do this on its
# own: $ErrorActionPreference has no bearing on a non-zero exit code.
# Deliberately without a param block: every argument then lands in $args as-is.
# Declared parameters would try to bind the tokens that start with a dash, and
# these commands are full of them (--install, -u, -subj).
function Invoke-Checked {
    if ($args.Count -eq 0) { throw 'Invoke-Checked needs a command to run' }
    $exe = $args[0]
    $arguments = @($args | Select-Object -Skip 1)
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "$exe exited with $LASTEXITCODE" }
}

# Runs an installer and waits for it. 3010 is "installed, but wants a reboot",
# which a container can't do and doesn't need, so callers allow it where it
# applies.
function Invoke-Installer {
    param (
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [int[]] $AllowedExitCodes = @(0)
    )
    $proc = Start-Process -FilePath $Path -Wait -PassThru -NoNewWindow -ArgumentList $Arguments
    Write-Host ('{0} exited with {1}' -f (Split-Path -Leaf $Path), $proc.ExitCode)
    if ($AllowedExitCodes -notcontains $proc.ExitCode) {
        throw "$Path failed with exit code $($proc.ExitCode)"
    }
}
