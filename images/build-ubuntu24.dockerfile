#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

FROM ubuntu:24.04 AS base

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


# clang 16 to 20
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

FROM base AS build-clang20
RUN \
    apt-get --no-install-recommends -y install \
        clang-20 \
        llvm-20 \
        libclang-rt-20-dev \
        libc++-20-dev \
        libc++abi-20-dev && \
    ln -s /usr/bin/clang++-20 /usr/bin/clang++ && \
    ln -s /usr/bin/clang-20 /usr/bin/clang


# Benchmark image, which extends gcc-14
# Installs libmysqlclient. This includes many directories we don't care about.
# Removing them reduces the image size.
# Includes in this tarfile are placed directly under include/,
# unlike the ones in deb packages. Move them to reproduce deb layout.
FROM build-gcc14 AS build-bench
RUN \
    apt-get --no-install-recommends -y install \
        wget \
        xz-utils \
        mariadb-client \
        libmariadb-dev && \
    wget -q https://dev.mysql.com/get/Downloads/MySQL-8.4/mysql-8.4.4-linux-glibc2.28-x86_64.tar.xz && \
        tar -xf mysql-8.4.4-linux-glibc2.28-x86_64.tar.xz && \
        mkdir -p /opt/mysql-8.4.4/include/mysql && \
        mv mysql-8.4.4-linux-glibc2.28-x86_64/lib /opt/mysql-8.4.4 && \
        mv mysql-8.4.4-linux-glibc2.28-x86_64/include/* /opt/mysql-8.4.4/include/mysql/ && \
        rm mysql-8.4.4-linux-glibc2.28-x86_64.tar.xz && \
        rm -rf mysql-8.4.4-linux-glibc2.28-x86_64
