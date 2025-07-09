#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

target "mytest-mariadb" {
    context = "."
    dockerfile = "images/mariadb.dockerfile"
    tags = [
        "mytest-mariadb:latest",
    ]
    args = {
        "BASE_IMAGE_VERSION" = "11.4.2"
    }
}

target "build-ubuntu18" {
    name = tgt
    matrix = {
        "tgt" = [
            "build-gcc6",
        ]
    }
    dockerfile = "images/build-ubuntu18.dockerfile"
    target = tgt
    tags = [
        "${tgt}:latest",
        "${tgt}:1",
    ]
}

target "build-ubuntu20" {
    name = tgt
    matrix = {
        "tgt" = [
            "build-gcc10",
            "build-clang7",
            "build-clang11",
        ]
    }
    dockerfile = "images/build-ubuntu20.dockerfile"
    target = tgt
    tags = [
        "${tgt}:latest",
        "${tgt}:1",
    ]
}

target "build-ubuntu22" {
    name = tgt
    matrix = {
        "tgt" = [
            "build-gcc11",
            "build-clang14",
        ]
    }
    dockerfile = "images/build-ubuntu22.dockerfile"
    target = tgt
    tags = [
        "${tgt}:latest",
        "${tgt}:1",
    ]
}


target "build-ubuntu24" {
    name = tgt
    matrix = {
        "tgt" = [
            "build-gcc13",
            "build-gcc14",
            "build-clang16",
            "build-clang17",
            "build-clang18",
            "build-clang19",
            "build-bench",
        ]
    }
    dockerfile = "images/build-ubuntu24.dockerfile"
    target = tgt
    tags = [
        "${tgt}:latest",
        "${tgt}:1",
    ]
}

target "build-clang16-i386" {
    dockerfile = "images/build-ubuntu24-i386.dockerfile"
    tags = [
        "build-clang16-i386:latest",
        "build-clang16-i386:1",
    ]
}

target "build-noopenssl" {
    dockerfile = "images/build-noopenssl.dockerfile"
    tags = [
        "build-noopenssl:latest",
        "build-noopenssl:1",
    ]
}

target "build-docs" {
    dockerfile = "images/build-docs.dockerfile"
    tags = [
        "build-docs:latest",
        "build-docs:1",
    ]
}
