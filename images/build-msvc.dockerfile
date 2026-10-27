#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# An image with a single MSVC toolset, selected with the B2_TOOLSET build arg.
# The cppalliance/dronevs images now ship every toolset from v141 to v145 in one
# ~14GB image, which doesn't fit in the CI disk, so we install just what we need:
# the Visual Studio part of this lands at 2.9GB (14.1) to 4.5GB (14.5).
# See .github/workflows/docker-windows.yml for the toolsets we build.
#
# Based on Windows Server 2025 with .NET Framework, which the VS installer needs.
# Running it requires a Server 2025 host, or Hyper-V isolation anywhere else.
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2025

# Be explicit about the shell: the commands below rely on cmd reporting their exit
# code back to docker, which powershell doesn't do reliably
SHELL ["cmd", "/S", "/C"]

ARG B2_TOOLSET

# The MSVC toolset, plus the b2 registration that exposes it as toolset=msvc-$B2_TOOLSET
COPY images/install-msvc.ps1 C:/tmp/install-msvc.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/install-msvc.ps1 -B2Toolset %B2_TOOLSET%

# Chocolatey, for everything else
RUN powershell -NoProfile -Command \
    "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
RUN choco feature enable -n allowGlobalConfirmation

# git clones the Boost superproject, python runs the CI scripts, cmake is used by
# the CMake pipelines
RUN choco install --no-progress -y git python
RUN choco install --no-progress -y cmake.install --installargs '"ADD_CMAKE_TO_PATH=System"'
RUN pip install requests

# The MySQL server the tests run against, and its config. Installed by hand rather
# than through chocolatey, whose package hardcodes a dev.mysql.com URL: that host
# is a redirector with bot protection in front of it, and it answers 403 to CI
# runners. This is the file it redirects to, and the checksum is the one the
# chocolatey package expects, so the bytes are the same either way.
COPY boost_mysql/win-ci.cnf C:/my.cnf
COPY boost_mysql/ssl C:/ssl
RUN powershell -NoProfile -Command \
    $ErrorActionPreference = 'Stop' ; \
    Invoke-WebRequest -UseBasicParsing -OutFile 'C:/tmp/mysql.zip' \
        -Uri 'https://cdn.mysql.com/archives/mysql-8.0/mysql-8.0.20-winx64.zip' ; \
    $expected = 'B9A7592AC170A6C55CE4F20C16E120C789D3D89342EA5681362311E118103A8A' ; \
    $actual = (Get-FileHash 'C:/tmp/mysql.zip' -Algorithm SHA256).Hash ; \
    if ($actual -ne $expected) { throw \"mysql.zip checksum mismatch: $actual\" } ; \
    Expand-Archive 'C:/tmp/mysql.zip' -DestinationPath 'C:/tmp/mysql' ; \
    New-Item -ItemType Directory -Force -Path 'C:/tools/mysql' | Out-Null ; \
    Move-Item 'C:/tmp/mysql/mysql-8.0.20-winx64' 'C:/tools/mysql/current' ; \
    Remove-Item -Recurse -Force 'C:/tmp/mysql', 'C:/tmp/mysql.zip'

# Initialize the server and register it as a service, as the chocolatey package
# did: same install location, same data directory, same passwordless root, which
# is what the CI scripts connect as. MySQL accepts forward slashes in option
# files. The server picks up basedir and datadir from this file and its SSL
# settings from C:\my.cnf, both of which are in its default search path.
RUN powershell -NoProfile -Command \
    $ErrorActionPreference = 'Stop' ; \
    @('[mysqld]', 'basedir=C:/tools/mysql/current', 'datadir=C:/ProgramData/MySQL/data', 'port=3306') \
        | Set-Content 'C:/tools/mysql/current/my.ini' -Encoding ascii ; \
    New-Item -ItemType Directory -Force -Path 'C:/ProgramData/MySQL/data' | Out-Null ; \
    & 'C:/tools/mysql/current/bin/mysqld.exe' --defaults-file='C:/tools/mysql/current/my.ini' --initialize-insecure ; \
    if ($LASTEXITCODE -ne 0) { throw 'mysqld --initialize-insecure failed' } ; \
    & 'C:/tools/mysql/current/bin/mysqld.exe' --install MySQL ; \
    if ($LASTEXITCODE -ne 0) { throw 'mysqld --install failed' } ; \
    Start-Service MySQL ; \
    & 'C:/tools/mysql/current/bin/mysql.exe' -u root --batch --skip-column-names -e 'SELECT VERSION()' ; \
    if ($LASTEXITCODE -ne 0) { throw 'the server did not answer as root' } ; \
    Stop-Service MySQL

# OpenSSL, in both address models, where the b2 and CMake builds expect it. This
# build ships x86, x64 and arm64 in a single archive, already laid out as
# bin/include/lib, so it's an extract rather than two installer runs into a fixed
# location. The chocolatey package wraps the Shining Light installers, which can
# only hold one address model at a time, hence the install/copy/reinstall/copy/
# uninstall it replaces.
# 3.5.x is the current LTS. The URL and the checksum below are the ones published
# at https://kb.firedaemon.com/support/solutions/articles/4000121705
RUN powershell -NoProfile -Command \
    $ErrorActionPreference = 'Stop' ; \
    Invoke-WebRequest -UseBasicParsing -OutFile 'C:/tmp/openssl.zip' \
        -Uri 'https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-3.5.9.zip' ; \
    $expected = '76DA391395BE029B44794857B9FF380255E02A0960A98314CD3F6A6816D82696' ; \
    $actual = (Get-FileHash 'C:/tmp/openssl.zip' -Algorithm SHA256).Hash ; \
    if ($actual -ne $expected) { throw \"openssl.zip checksum mismatch: $actual\" } ; \
    Expand-Archive 'C:/tmp/openssl.zip' -DestinationPath 'C:/tmp/openssl' ; \
    Move-Item 'C:/tmp/openssl/x86' 'C:/openssl-32' ; \
    Move-Item 'C:/tmp/openssl/x64' 'C:/openssl-64' ; \
    Copy-Item 'C:/tmp/openssl/LICENSE.txt' 'C:/openssl-32' ; \
    Copy-Item 'C:/tmp/openssl/LICENSE.txt' 'C:/openssl-64' ; \
    Remove-Item -Recurse -Force 'C:/tmp/openssl', 'C:/tmp/openssl.zip' ; \
    Get-ChildItem 'C:/openssl-32', 'C:/openssl-64' -Recurse -Filter *.pdb | Remove-Item -Force

# The MySQL client, and the OpenSSL DLLs: the .lib files are import libraries, so
# the test binaries load the DLLs at run time. The two address models use different
# DLL names, so both directories can sit on PATH. Written through the registry
# rather than with setx, which truncates PATH at 1024 characters.
RUN powershell -NoProfile -Command \
    $ErrorActionPreference = 'Stop' ; \
    $old = [Environment]::GetEnvironmentVariable('Path', 'Machine') ; \
    $new = 'C:\tools\mysql\current\bin;C:\openssl-64\bin;C:\openssl-32\bin;' + $old ; \
    [Environment]::SetEnvironmentVariable('Path', $new, 'Machine')

ENTRYPOINT ["powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]
