#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

tag_prefix = "ghcr.io/anarthal/cpp-ci-containers"

#
# Databases
#
target "mysql-5_7_41" {
    dockerfile = "images/mysql.dockerfile"
    tags = [
        "${tag_prefix}/mysql-5_7_41:latest",
        "${tag_prefix}/mysql-5_7_41:1",
    ]
    args = {
        "BASE_IMAGE_VERSION" = "5.7.41"
    }
}


target "mysql-8_4_1" {
    dockerfile = "images/mysql.dockerfile"
    tags = [
        "${tag_prefix}/mysql-8_4_1:latest",
        "${tag_prefix}/mysql-8_4_1:1",
    ]
    args = {
        "BASE_IMAGE_VERSION" = "8.4.1"
        "ENTRYPOINT_ARGS" = "--mysql-native-password=ON"
    }
    platforms = [ "linux/amd64", "linux/arm64/v8" ]
}

target "mysql-9_4_0" {
    dockerfile = "images/mysql.dockerfile"
    tags = [
        "${tag_prefix}/mysql-9_4_0:latest",
        "${tag_prefix}/mysql-9_4_0:1",
    ]
    args = {
        "BASE_IMAGE_VERSION" = "9.4.0"
    }
}

target "mariadb-11_4_2" {
    dockerfile = "images/mariadb.dockerfile"
    tags = [
        "${tag_prefix}/mariadb-11_4_2:latest",
        "${tag_prefix}/mariadb-11_4_2:1",
    ]
    args = {
        "BASE_IMAGE_VERSION" = "11.4.2"
    }
}

group "databases" {
    targets = [ 
        "mysql-5_7_41",
        "mysql-8_4_1",
        "mysql-9_4_0",
        "mariadb-11_4_2",
    ]
}

#
# Linux containers
#

target "build-ubuntu16" {
    matrix = {
        "tgt" = [
            { "name": "build-gcc5",     "version": 1 },
            { "name": "build-clang3_6", "version": 1 },
            { "name": "build-cmake3_8", "version": 3 },
        ]
    }
    name = tgt.name
    dockerfile = "images/build-ubuntu16.dockerfile"
    target = tgt.name
    tags = [
        "${tag_prefix}/${tgt.name}:latest",
        "${tag_prefix}/${tgt.name}:${tgt.version}",
    ]
}

target "build-ubuntu18" {
    matrix = {
        "tgt" = [
            { "name": "build-gcc6", "version": 1 },
        ]
    }
    name = tgt.name
    dockerfile = "images/build-ubuntu18.dockerfile"
    target = tgt.name
    tags = [
        "${tag_prefix}/${tgt.name}:latest",
        "${tag_prefix}/${tgt.name}:${tgt.version}",
    ]
}

target "build-ubuntu20" {
    matrix = {
        "tgt" = [
            { "name": "build-gcc10",   "version": 1 },
            { "name": "build-clang7",  "version": 1 },
            { "name": "build-clang11", "version": 1 },
        ]
    }
    name = tgt.name
    dockerfile = "images/build-ubuntu20.dockerfile"
    target = tgt.name
    tags = [
        "${tag_prefix}/${tgt.name}:latest",
        "${tag_prefix}/${tgt.name}:${tgt.version}",
    ]
}

target "build-ubuntu22" {
    matrix = {
        "tgt" = [
            { "name": "build-gcc11",   "version": 1 },
            { "name": "build-clang14", "version": 1 },
        ]
    }
    name = tgt.name
    dockerfile = "images/build-ubuntu22.dockerfile"
    target = tgt.name
    platforms = [ "linux/amd64", "linux/arm64/v8" ]
    tags = [
        "${tag_prefix}/${tgt.name}:latest",
        "${tag_prefix}/${tgt.name}:${tgt.version}",
    ]
}


target "build-ubuntu24" {
    matrix = {
        "tgt" = [
            { "name": "build-gcc13",   "version": 1 },
            { "name": "build-gcc14",   "version": 1 },
            { "name": "build-clang16", "version": 1 },
            { "name": "build-clang17", "version": 1 },
            { "name": "build-clang18", "version": 1 },
            { "name": "build-clang19", "version": 1 },
            { "name": "build-bench",   "version": 1 },
        ]
    }
    name = tgt.name
    dockerfile = "images/build-ubuntu24.dockerfile"
    target = tgt.name
    tags = [
        "${tag_prefix}/${tgt.name}:latest",
        "${tag_prefix}/${tgt.name}:${tgt.version}",
    ]
}

target "build-clang16-i386" {
    dockerfile = "images/build-ubuntu24-i386.dockerfile"
    tags = [
        "${tag_prefix}/build-clang16-i386:latest",
        "${tag_prefix}/build-clang16-i386:1",
    ]
}

target "build-noopenssl" {
    dockerfile = "images/build-noopenssl.dockerfile"
    tags = [
        "${tag_prefix}/build-noopenssl:latest",
        "${tag_prefix}/build-noopenssl:1",
    ]
}

target "build-docs" {
    dockerfile = "images/build-docs.dockerfile"
    tags = [
        "${tag_prefix}/build-docs:latest",
        "${tag_prefix}/build-docs:1",
    ]
}

group "linux-others" {
    targets = [ 
        "build-clang16-i386",
        "build-noopenssl",
        "build-docs",
    ]
}

group "linux" {
    targets = [ 
        "build-ubuntu16",
        "build-ubuntu18",
        "build-ubuntu20",
        "build-ubuntu22",
        "build-ubuntu24",
        "linux-others",
    ]
}

#
# Windows
#

target "build-msvc" {
    matrix = {
        "config" = [
            { "tgt" = "build-msvc14_1", "base_image" = "cppalliance/dronevs2017:1" },
            { "tgt" = "build-msvc14_2", "base_image" = "cppalliance/dronevs2019:1" },
            { "tgt" = "build-msvc14_3", "base_image" = "cppalliance/dronevs2022:1" },
        ]
    }
    name = config.tgt
    dockerfile = "images/build-msvc.dockerfile"
    tags = [
        "${tag_prefix}/${config.tgt}:latest",
        "${tag_prefix}/${config.tgt}:1",
    ]
    args = {
        "BASE_IMAGE" = config.base_image
    }
}

group "windows" {
    targets = [ "build-msvc" ]
}
