#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Installs git, CMake and Python, plus the VC runtime. See build-msvc.dockerfile.
#
# These used to come from chocolatey, which pulled 15 packages for two of them:
# three chocolatey extensions, five Windows 7/8.1-era hotfix shims (KB2919355 and
# friends, inapplicable to Server 2025), two VC++ redistributables and a
# meta-package per tool. All three publish a plain archive or a silent installer,
# with a checksum, which is what this uses.

$ErrorActionPreference = 'Stop'

function Get-Verified {
    param ([string] $Url, [string] $Sha256, [string] $OutFile)
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $OutFile
    $actual = (Get-FileHash $OutFile -Algorithm SHA256).Hash
    if ($actual -ne $Sha256) { throw "$Url checksum mismatch: $actual" }
}

function Add-MachinePath {
    param ([string] $Dir)
    $path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::SetEnvironmentVariable('Path', "$Dir;$path", 'Machine')
    $env:Path = "$Dir;$env:Path"
}

# git, to clone the Boost superproject. MinGit is the distribution git-for-windows
# publishes for embedding in other tools: the same git, without the bash and perl
# environment around it. Everything the CI does is clone and submodule update.
# Checksum from the release notes of https://github.com/git-for-windows/git
Get-Verified -OutFile 'C:\tmp\mingit.zip' `
    -Url 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/MinGit-2.56.0.4-64-bit.zip' `
    -Sha256 'E3BF78351FE777FBA47DDEE5950082F8A98BB0F02604FDC7BA3EE2CB68FFA877'
Expand-Archive -Path 'C:\tmp\mingit.zip' -DestinationPath 'C:\git'
Remove-Item -Force 'C:\tmp\mingit.zip'
Add-MachinePath 'C:\git\cmd'

# CMake, for the CMake pipelines. Checksum from the release's SHA-256 file.
Get-Verified -OutFile 'C:\tmp\cmake.zip' `
    -Url 'https://github.com/Kitware/CMake/releases/download/v4.4.4/cmake-4.4.4-windows-x86_64.zip' `
    -Sha256 'BACE36E94B31C68AB6FA295F26DFA11219E0701CF7C94B0284A7D1CB13DAC536'
Expand-Archive -Path 'C:\tmp\cmake.zip' -DestinationPath 'C:\tmp\cmake'
Move-Item 'C:\tmp\cmake\cmake-4.4.4-windows-x86_64' 'C:\cmake'
Remove-Item -Recurse -Force 'C:\tmp\cmake', 'C:\tmp\cmake.zip'
Add-MachinePath 'C:\cmake\bin'

# Python, to run the CI scripts. The embeddable package is a third of the size but
# ships without pip, so this is the regular installer with the parts a CI image
# has no use for left out: the test suite, the docs, tkinter and IDLE, the headers
# and libs for embedding, and the py.exe launcher.
# Checksum from https://www.python.org/downloads/release/python-3152/
Get-Verified -OutFile 'C:\tmp\python.exe' `
    -Url 'https://www.python.org/ftp/python/3.15.2/python-3.15.2-amd64.exe' `
    -Sha256 '06E225A228191B0F4D1DCF6905FBB21BF9F6970D13A2EC63137AB9BEE76F15AA'
$proc = Start-Process -FilePath 'C:\tmp\python.exe' -Wait -PassThru -NoNewWindow -ArgumentList @(
    '/quiet', 'InstallAllUsers=1', 'PrependPath=1',
    'Include_test=0', 'Include_doc=0', 'Include_tcltk=0', 'Include_dev=0', 'Include_launcher=0'
)
if ($proc.ExitCode -ne 0) { throw "the Python installer failed with exit code $($proc.ExitCode)" }
Remove-Item -Force 'C:\tmp\python.exe'

# PrependPath only affects new processes, so this one needs telling
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine')

# requests, used by the examples under example/private
python -m pip install --no-cache-dir --disable-pip-version-check requests
if ($LASTEXITCODE -ne 0) { throw 'pip install requests failed' }

# Note there is no VC runtime installed system-wide. chocolatey used to pull one
# in as a dependency of its python package, but nothing needs it: every
# bin\Host*\<target> directory of the toolset carries msvcp140.dll, msvcp140_1.dll,
# msvcp140_2.dll and vcruntime140.dll next to cl.exe, in the matching address
# model, and vcvarsall puts that directory on PATH. Anything run from a developer
# environment - b2's tests, and ctest when the CMake jobs are launched the same
# way - finds the runtime there.

git --version
cmake --version
python --version
