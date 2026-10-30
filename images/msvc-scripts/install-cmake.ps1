#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Installs CMake, used by the CMake pipelines. See ../build-msvc.dockerfile.
#
# The "Visual Studio 18 2026" generator needs CMake 4.2 or newer.

# Load the utilities
. (Join-Path $PSScriptRoot 'common.ps1')

# Checksum from the release's SHA-256 file
$version = '4.4.4'
Expand-Verified -DestinationPath 'C:\tmp\cmake' `
    -Url "https://github.com/Kitware/CMake/releases/download/v$version/cmake-$version-windows-x86_64.zip" `
    -Sha256 'BACE36E94B31C68AB6FA295F26DFA11219E0701CF7C94B0284A7D1CB13DAC536'
Move-Item "C:\tmp\cmake\cmake-$version-windows-x86_64" 'C:\cmake'
Remove-Item -Recurse -Force 'C:\tmp\cmake'
Add-MachinePath 'C:\cmake\bin'

Invoke-Checked cmake --version
