#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

FROM ubuntu:22.04 AS base

RUN \
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

# gcc 11
FROM base AS build-gcc11

RUN \
    apt-get --no-install-recommends -y install \
        gcc-11 \
        g++-11 && \
    ln -s /usr/bin/g++-11 /usr/bin/g++ && \
    ln -s /usr/bin/gcc-11 /usr/bin/gcc

# clang 14
FROM base AS build-clang14

RUN \
    apt-get --no-install-recommends -y install \
        clang-14 \
        llvm-14 \
        libc++-14-dev \
        libc++abi-14-dev && \
    ln -s /usr/bin/clang++-14 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-14 /usr/bin/clang
