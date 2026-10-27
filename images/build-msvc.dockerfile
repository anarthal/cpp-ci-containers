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

# OpenSSL, in both address models, where the b2 and CMake builds expect it
RUN powershell -Command \
    $ErrorActionPreference = 'Stop' ; \
    $OPENSSL_VERSION = '1.1.1.1900' ; \
    choco install --no-progress -y --force --forceX86 --version $OPENSSL_VERSION openssl ; \
    Copy-Item 'C:/Program Files (x86)/OpenSSL-Win32/' -Recurse -Destination 'C:/openssl-32/' ; \
    choco install --no-progress -y --force --version $OPENSSL_VERSION openssl ; \
    Copy-Item 'C:/Program Files/OpenSSL-Win64/' -Recurse -Destination 'C:/openssl-64/' ; \
    choco uninstall -y openssl

ENTRYPOINT ["powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]
