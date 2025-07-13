#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

FROM ubuntu:20.04 AS base

RUN \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
        libssl-dev \
        git \
        ca-certificates \
        python3 \
        python3-requests \
        python-is-python3 \
        cmake \
        ninja-build \
        valgrind \
        gpg \
        gpg-agent \
        mysql-client

# gcc 10
FROM base AS build-gcc10

RUN \
    apt-get --no-install-recommends -y install \
        gcc-10 \
        g++-10 && \
    ln -s /usr/bin/g++-10 /usr/bin/g++ && \
    ln -s /usr/bin/gcc-10 /usr/bin/gcc

# clang-7
FROM base AS build-clang7

RUN \
    apt-get --no-install-recommends -y install \
        clang-7 \
        llvm-7 && \
    ln -s /usr/bin/clang++-7 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-7 /usr/bin/clang

# clang-11
FROM base AS build-clang11

RUN \
    apt-get --no-install-recommends -y install \
        clang-11 \
        llvm-11 && \
    ln -s /usr/bin/clang++-11 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-11 /usr/bin/clang

