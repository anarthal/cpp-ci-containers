#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

FROM ubuntu:26.04 AS base

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

# gcc 15 and 16
FROM base AS build-gcc15

RUN \
    apt-get --no-install-recommends -y install \
        gcc-15 \
        g++-15 && \
    ln -s /usr/bin/g++-15 /usr/bin/g++ && \
    ln -s /usr/bin/gcc-15 /usr/bin/gcc

FROM base AS build-gcc16

RUN \
    apt-get --no-install-recommends -y install \
        gcc-16 \
        g++-16 && \
    ln -s /usr/bin/g++-16 /usr/bin/g++ && \
    ln -s /usr/bin/gcc-16 /usr/bin/gcc


# clang 21 and 22
FROM base AS build-clang21
RUN \
    apt-get --no-install-recommends -y install \
        clang-21 \
        llvm-21 \
        libclang-rt-21-dev \
        libc++-21-dev \
        libc++abi-21-dev && \
    ln -s /usr/bin/clang++-21 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-21 /usr/bin/clang

FROM base AS build-clang22
RUN \
    apt-get --no-install-recommends -y install \
        clang-22 \
        llvm-22 \
        libclang-rt-22-dev \
        libc++-22-dev \
        libc++abi-22-dev && \
    ln -s /usr/bin/clang++-22 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-22 /usr/bin/clang
