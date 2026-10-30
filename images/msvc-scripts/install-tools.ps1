#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Installs git, CMake and Python. See ../build-msvc.dockerfile.
#
# These used to come from chocolatey, which pulled 15 packages for two of them:
# three chocolatey extensions, five Windows 7/8.1-era hotfix shims (KB2919355 and
# friends, inapplicable to Server 2025), two VC++ redistributables and a
# meta-package per tool. All three publish a plain archive or a silent installer,
# with a checksum, which is what this uses.

# Load the utilities
. (Join-Path $PSScriptRoot 'common.ps1')

# git, to clone the Boost superproject. MinGit is the distribution git-for-windows
# publishes for embedding in other tools: the same git, without the bash and perl
# environment around it. Everything the CI does is clone and submodule update.
# Checksum from the release notes of https://github.com/git-for-windows/git
Expand-Verified -DestinationPath 'C:\git' `
    -Url 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/MinGit-2.56.0.4-64-bit.zip' `
    -Sha256 'E3BF78351FE777FBA47DDEE5950082F8A98BB0F02604FDC7BA3EE2CB68FFA877'
Add-MachinePath 'C:\git\cmd'

# CMake, for the CMake pipelines. Checksum from the release's SHA-256 file.
Expand-Verified -DestinationPath 'C:\tmp\cmake' `
    -Url 'https://github.com/Kitware/CMake/releases/download/v4.4.4/cmake-4.4.4-windows-x86_64.zip' `
    -Sha256 'BACE36E94B31C68AB6FA295F26DFA11219E0701CF7C94B0284A7D1CB13DAC536'
Move-Item 'C:\tmp\cmake\cmake-4.4.4-windows-x86_64' 'C:\cmake'
Remove-Item -Recurse -Force 'C:\tmp\cmake'
Add-MachinePath 'C:\cmake\bin'

# Python, to run the CI scripts. The embeddable package is a third of the size but
# ships without pip, so this is the regular installer with the parts a CI image
# has no use for left out: the test suite, the docs, tkinter and IDLE, the headers
# and libs for embedding, and the py.exe launcher.
# Checksum from https://www.python.org/downloads/release/python-3152/
Get-Verified -OutFile 'C:\tmp\python.exe' `
    -Url 'https://www.python.org/ftp/python/3.15.2/python-3.15.2-amd64.exe' `
    -Sha256 '06E225A228191B0F4D1DCF6905FBB21BF9F6970D13A2EC63137AB9BEE76F15AA'
Invoke-Installer -Path 'C:\tmp\python.exe' -Arguments @(
    '/quiet', 'InstallAllUsers=1', 'PrependPath=1',
    'Include_test=0', 'Include_doc=0', 'Include_tcltk=0', 'Include_dev=0', 'Include_launcher=0'
)
Remove-Item -Force 'C:\tmp\python.exe'

# PrependPath only affects new processes, so this one needs telling
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine')

# requests, used by the examples under example/private
Invoke-Checked python -m pip install --no-cache-dir --disable-pip-version-check requests

# Note there is no VC runtime installed system-wide. chocolatey used to pull one
# in as a dependency of its python package, but nothing needs it: every
# bin\Host*\<target> directory of the toolset carries msvcp140.dll, msvcp140_1.dll,
# msvcp140_2.dll and vcruntime140.dll next to cl.exe, in the matching address
# model, and vcvarsall puts that directory on PATH. Anything run from a developer
# environment - b2's tests, and ctest when the CMake jobs are launched the same
# way - finds the runtime there.

Invoke-Checked git --version
Invoke-Checked cmake --version
Invoke-Checked python --version
