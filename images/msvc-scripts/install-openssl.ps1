#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Load the utilities
. (Join-Path $PSScriptRoot 'common.ps1')

# This zip ships x86, x64 and arm64 in a single archive, already laid out as
# bin/include/lib. It allows installing both architectures in a simple way,
# as opposed to the Chocolatey package or the Fire Daemon installer.
# 3.5.x is the current LTS. This URL and checksum are the ones published at
# https://kb.firedaemon.com/support/solutions/articles/4000121705
$version = '3.5.9'
$url = "https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-$version.zip"
$sha256 = '76DA391395BE029B44794857B9FF380255E02A0960A98314CD3F6A6816D82696'
$extracted = 'C:\tmp\openssl'

# The binaries have some baked-in paths. For instance, they look for config files
# under Common Files. We try to mimic what the installers would do.
# We have a smoke test to check for problems.
$shortVersion = ($version -split '\.')[0, 1] -join '.'
$roots = @{
    '64' = "C:\Program Files\FireDaemon OpenSSL $shortVersion"
    '32' = "C:\Program Files (x86)\FireDaemon OpenSSL $shortVersion"
}
$configDir = "C:\Program Files\Common Files\FireDaemon SSL $shortVersion"

Expand-Verified -Url $url -Sha256 $sha256 -DestinationPath $extracted
Move-Item (Join-Path $extracted 'x64') $roots['64']
Copy-Item (Join-Path $extracted 'LICENSE.txt') $roots['64']
Move-Item (Join-Path $extracted 'x86') $roots['32']
Copy-Item (Join-Path $extracted 'LICENSE.txt') $roots['32']
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
Copy-Item (Join-Path $extracted 'ssl\*') $configDir -Recurse -Force # config

# Remove the arm64 build along with the rest of the archive
Remove-Item -Recurse -Force $extracted

# Remove debug symbols, which are heavyweight
Get-ChildItem $roots.Values -Recurse -Filter *.pdb | Remove-Item -Force

# DLLs are under bin. Add it to path so the loader finds them
foreach ($arch in '32', '64') { Add-MachinePath (Join-Path $roots[$arch] 'bin') }

# Make b2 find OpenSSL. Append because other install scripts do similar things
$usingOpenssl = foreach ($arch in '64', '32') {
    'using openssl : : <include>"{0}/include" <search>"{0}/lib" <ssl-name>libssl <crypto-name>libcrypto : <address-model>{1} ;' `
        -f ($roots[$arch] -replace '\\', '/'), $arch
}
Add-Content -Path 'C:\Windows\site-config.jam' -Value $usingOpenssl -Encoding ascii
Write-Host '=== C:\Windows\site-config.jam ==='
Get-Content 'C:\Windows\site-config.jam' | Write-Host

# Same for CMake. We need to choose architecture here though.
# All of our CMake builds are 64-bit, so this is fine.
[Environment]::SetEnvironmentVariable('CMAKE_PREFIX_PATH', $roots['64'], 'Machine')


# Check that the DLLs load and the config files can be located
foreach ($arch in '32', '64') {
    $exe = Join-Path $roots[$arch] 'bin\openssl.exe'
    Invoke-Checked $exe version
    Invoke-Checked $exe req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=smoke test' `
        -keyout 'C:\tmp\smoke-key.pem' -out 'C:\tmp\smoke-cert.pem'
}
Remove-Item -Force 'C:\tmp\smoke-key.pem', 'C:\tmp\smoke-cert.pem'
