#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

FROM ubuntu:24.04 AS base

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

# gcc 13 and 14
FROM base AS build-gcc13

RUN \
    apt-get --no-install-recommends -y install \
        gcc-13 \
        g++-13 && \
    ln -s /usr/bin/g++-13 /usr/bin/g++ && \
    ln -s /usr/bin/gcc-13 /usr/bin/gcc

FROM base AS build-gcc14

RUN \
    apt-get --no-install-recommends -y install \
        gcc-14 \
        g++-14 && \
    ln -s /usr/bin/g++-14 /usr/bin/g++ && \
    ln -s /usr/bin/gcc-14 /usr/bin/gcc


# clang 16 to 19
FROM base AS build-clang16
RUN \
    apt-get --no-install-recommends -y install \
        clang-16 \
        llvm-16 \
        libclang-rt-16-dev \
        libc++-16-dev \
        libc++abi-16-dev && \
    ln -s /usr/bin/clang++-16 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-16 /usr/bin/clang

FROM base AS build-clang17
RUN \
    apt-get --no-install-recommends -y install \
        clang-17 \
        llvm-17 \
        libclang-rt-17-dev \
        libc++-17-dev \
        libc++abi-17-dev && \
    ln -s /usr/bin/clang++-17 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-17 /usr/bin/clang

FROM base AS build-clang18
RUN \
    apt-get --no-install-recommends -y install \
        clang-18 \
        llvm-18 \
        libclang-rt-18-dev \
        libc++-18-dev \
        libc++abi-18-dev && \
    ln -s /usr/bin/clang++-18 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-18 /usr/bin/clang

FROM base AS build-clang19
RUN \
    apt-get --no-install-recommends -y install \
        clang-19 \
        llvm-19 \
        libclang-rt-19-dev \
        libc++-19-dev \
        libc++abi-19-dev && \
    ln -s /usr/bin/clang++-19 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-19 /usr/bin/clang
