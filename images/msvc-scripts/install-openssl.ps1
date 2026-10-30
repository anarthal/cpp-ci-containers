#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Installs OpenSSL in both address models, and tells b2 and CMake where it is.
# See ../build-msvc.dockerfile.

# Load the utilities
. (Join-Path $PSScriptRoot 'common.ps1')

# This build ships x86, x64 and arm64 in a single archive, already laid out as
# bin/include/lib, which is why it replaced the chocolatey package: that one wraps
# the Shining Light installers, which can only hold one address model at a time.
# There is no 32-bit installer to use instead - the vendor publishes an x64 one
# and this archive, nothing else.
# 3.5.x is the current LTS. This URL and checksum are the ones published at
# https://kb.firedaemon.com/support/solutions/articles/4000121705
$version = '3.5.9'
$url = "https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-$version.zip"
$sha256 = '76DA391395BE029B44794857B9FF380255E02A0960A98314CD3F6A6816D82696'
$extracted = 'C:\tmp\openssl'

# Everything goes where these binaries were built to look for it, which is where
# the vendor's installer would have put it: both address models share one
# configuration directory under Common Files, and each has its own root holding
# the provider modules. The directory names carry the major.minor version. If a
# version bump ever moves them, the certificate at the end of this script fails,
# because the binaries won't find their configuration.
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
Copy-Item (Join-Path $extracted 'ssl\*') $configDir -Recurse -Force

# This drops the arm64 build along with the rest of the archive
Remove-Item -Recurse -Force $extracted

# Debug symbols, 98MB of the 124MB that x86 and x64 weigh together
Get-ChildItem $roots.Values -Recurse -Filter *.pdb | Remove-Item -Force

# The .lib files are import libraries, so the test binaries load the DLLs at run
# time. The two address models use different DLL names, so both directories can
# sit on PATH.
foreach ($arch in '32', '64') { Add-MachinePath (Join-Path $roots[$arch] 'bin') }

# b2 reads site-config.jam from %SystemRoot% on every run, so the image can say
# where OpenSSL is instead of every consumer hardcoding it. install-msvc.ps1
# writes the toolset into the same file, which is why this appends.
$usingOpenssl = foreach ($arch in '64', '32') {
    'using openssl : : <include>"{0}/include" <search>"{0}/lib" <ssl-name>libssl <crypto-name>libcrypto : <address-model>{1} ;' `
        -f ($roots[$arch] -replace '\\', '/'), $arch
}
Add-Content -Path 'C:\Windows\site-config.jam' -Value $usingOpenssl -Encoding ascii
Write-Host '=== C:\Windows\site-config.jam ==='
Get-Content 'C:\Windows\site-config.jam' | Write-Host

# The same for CMake: the archive ships lib\cmake\OpenSSL\OpenSSLConfig.cmake, so
# find_package(OpenSSL) resolves in config mode once this prefix is in the search
# path. CMake adds the environment variable to whatever -DCMAKE_PREFIX_PATH the
# caller passes rather than replacing it. One prefix means one address model: a
# 32-bit CMake build would have to point at the other root itself.
[Environment]::SetEnvironmentVariable('CMAKE_PREFIX_PATH', $roots['64'], 'Machine')


# Confirms the DLLs next to it load, and that the configuration landed where the
# binaries look for it: generating a certificate is what the CI does with openssl,
# and it's the step that reads openssl.cnf.
foreach ($arch in '32', '64') {
    $exe = Join-Path $roots[$arch] 'bin\openssl.exe'
    Invoke-Checked $exe version
    Invoke-Checked $exe req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=smoke test' `
        -keyout 'C:\tmp\smoke-key.pem' -out 'C:\tmp\smoke-cert.pem'
}
Remove-Item -Force 'C:\tmp\smoke-key.pem', 'C:\tmp\smoke-cert.pem'
