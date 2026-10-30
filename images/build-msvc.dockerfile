#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

# Inspired by cppalliance/dronevs, but with an emphasis in making the image minimal.
# We encountered problems when using cppalliance/dronevs as base because it's big
# and doesn't fit in GHA hosted runner's disks.
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2025

# Be explicit about the shell: the commands below rely on cmd reporting their exit
# code back to docker, which powershell doesn't do reliably
SHELL ["cmd", "/S", "/C"]

ARG B2_TOOLSET

# Copy the required files
COPY images/msvc-scripts C:/tmp/msvc-scripts
COPY boost_mysql/ssl C:/ssl

# Install all the tools we need
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-msvc.ps1 -B2Toolset %B2_TOOLSET%
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-git.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-cmake.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-python.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-openssl.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:/tmp/msvc-scripts/install-mysql.ps1

ENTRYPOINT ["powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]
