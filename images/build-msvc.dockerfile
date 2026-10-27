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

# The MySQL server the tests run against, and its config
COPY boost_mysql/win-ci.cnf C:/my.cnf
COPY boost_mysql/ssl C:/ssl
RUN choco install --no-progress -y mysql --version 8.0.20

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

# The .lib files are import libraries, so the test binaries load the DLLs at run
# time. The two address models use different DLL names, so both can be on PATH.
RUN setx /M PATH "C:\openssl-64\bin;C:\openssl-32\bin;%PATH%"

ENTRYPOINT ["powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]
