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

COPY images/msvc-scripts C:/tmp/msvc-scripts

# The MSVC toolset, plus the b2 registration that exposes it as toolset=msvc-$B2_TOOLSET
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-msvc.ps1 -B2Toolset %B2_TOOLSET%

# git clones the Boost superproject, python runs the CI scripts, cmake is used by
# the CMake pipelines. These used to come from chocolatey, which pulled in 15
# packages for the three of them, five of those Windows 7/8.1-era hotfix shims.
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-git.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-cmake.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-python.ps1

# The MySQL server the tests run against, and its config
COPY boost_mysql/ssl C:/ssl
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-mysql.ps1

# OpenSSL, in both address models
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-openssl.ps1

ENTRYPOINT ["powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]
