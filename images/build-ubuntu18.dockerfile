#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

FROM ubuntu:18.04 AS base

RUN \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
        libssl-dev \
        git \
        ca-certificates \
        python3 \
        python3-requests \
        cmake \
        ninja-build \
        valgrind \
        gpg \
        gpg-agent \
        mysql-client && \
    ln -s /usr/bin/python3 /usr/bin/python

# gcc 6
FROM base AS build-gcc6

RUN \
    apt-get --no-install-recommends -y install \
        gcc-6 \
        g++-6 && \
    ln -s /usr/bin/g++-6 /usr/bin/g++ && \
    ln -s /usr/bin/gcc-6 /usr/bin/gcc
