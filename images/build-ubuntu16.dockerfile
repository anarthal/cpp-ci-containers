#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

FROM ubuntu:16.04 AS base

RUN \
    apt-get update && \
    apt-get --no-install-recommends -y install \
        libssl-dev \
        git \
        ca-certificates \
        python3 \
        python3-requests \
        ninja-build \
        valgrind \
        gpg \
        gpg-agent \
        mysql-client && \
    ln -s /usr/bin/python3 /usr/bin/python

# gcc 5
FROM base AS build-gcc5

RUN \
    apt-get --no-install-recommends -y install \
        cmake \
        gcc-5 \
        g++-5 && \
    ln -s /usr/bin/g++-5 /usr/bin/g++ && \
    ln -s /usr/bin/gcc-5 /usr/bin/gcc

# clang 3.6
FROM base AS build-clang3_6

RUN \
    apt-get --no-install-recommends -y install \
        cmake \
        clang-3.6 \
        llvm-3.6 && \
    ln -s /usr/bin/clang++-3.6 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-3.6 /usr/bin/clang

# cmake 3.8
FROM base AS build-cmake3_8

RUN \
    mkdir -p ~/cmake && \
    CMAKE_VERSION=3.8.0 && \
    curl -OLs https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-SHA-256.txt && \
    curl -OLs https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-x86_64.sh && \
    sha256sum -c --ignore-missing cmake-${CMAKE_VERSION}-SHA-256.txt && \
    curl -OLs https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-SHA-256.txt.asc && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys C6C265324BBEBDC350B513D02D2CEF1034921684 && \
    gpg --verify cmake-${CMAKE_VERSION}-SHA-256.txt.asc cmake-${CMAKE_VERSION}-SHA-256.txt && \
    bash cmake-${CMAKE_VERSION}-Linux-x86_64.sh --skip-license && \
    cd ~ && \
    rm -rf ~/cmake && \
    cmake --version
