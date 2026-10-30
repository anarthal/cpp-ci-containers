#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Installs OpenSSL in both address models, where the b2 and CMake builds expect
# it. See ../build-msvc.dockerfile.

# Load the utilities
. (Join-Path $PSScriptRoot 'common.ps1')

# This build ships x86, x64 and arm64 in a single archive, already laid out as
# bin/include/lib, so this is an extract rather than two installer runs into a
# fixed location. The chocolatey package wraps the Shining Light installers, which
# can only hold one address model at a time, hence the install/copy/reinstall/
# copy/uninstall it replaces.
# 3.5.x is the current LTS. This URL and checksum are the ones published at
# https://kb.firedaemon.com/support/solutions/articles/4000121705
$url = 'https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-3.5.9.zip'
$sha256 = '76DA391395BE029B44794857B9FF380255E02A0960A98314CD3F6A6816D82696'
$extracted = 'C:\tmp\openssl'

Expand-Verified -Url $url -Sha256 $sha256 -DestinationPath $extracted
Move-Item (Join-Path $extracted 'x86') 'C:\openssl-32'
Move-Item (Join-Path $extracted 'x64') 'C:\openssl-64'
foreach ($dir in 'C:\openssl-32', 'C:\openssl-64') {
    Copy-Item (Join-Path $extracted 'LICENSE.txt') $dir
}

# The configuration goes where these binaries were compiled to look for it, which
# is where the vendor's installer would have put it: a directory under Common
# Files that both address models share. Without it everything that reads
# openssl.cnf fails with "Can't open ... for reading". The path carries the
# version number, so ask the binaries for it instead of hardcoding it.
$opensslDirs = @('C:\openssl-64\bin\openssl.exe', 'C:\openssl-32\bin\openssl.exe') |
    ForEach-Object { (& $_ version -d) -replace '^OPENSSLDIR:\s*"?(.*?)"?\s*$', '$1' } |
    Select-Object -Unique
foreach ($dir in $opensslDirs) {
    Write-Host ('Installing openssl.cnf to {0}' -f $dir)
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Copy-Item (Join-Path $extracted 'ssl\*') $dir -Recurse -Force
}

# This drops the arm64 build along with the rest of the archive
Remove-Item -Recurse -Force $extracted

# Debug symbols, 98MB of the 124MB that x86 and x64 weigh together
Get-ChildItem 'C:\openssl-32', 'C:\openssl-64' -Recurse -Filter *.pdb | Remove-Item -Force

# The .lib files are import libraries, so the test binaries load the DLLs at run
# time. The two address models use different DLL names, so both directories can
# sit on PATH. Written through the registry rather than with setx, which
# truncates PATH at 1024 characters.
Add-MachinePath 'C:\openssl-32\bin'
Add-MachinePath 'C:\openssl-64\bin'

# Confirms the DLLs next to it load, and that the configuration is where the
# tools look for it: generating a certificate is what the CI does with openssl,
# and it's the step that reads openssl.cnf.
foreach ($exe in 'C:\openssl-32\bin\openssl.exe', 'C:\openssl-64\bin\openssl.exe') {
    Invoke-Checked $exe version
    Invoke-Checked $exe req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=smoke test' `
        -keyout 'C:\tmp\smoke-key.pem' -out 'C:\tmp\smoke-cert.pem'
}
Remove-Item -Force 'C:\tmp\smoke-key.pem', 'C:\tmp\smoke-cert.pem'
