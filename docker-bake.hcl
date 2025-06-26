# COPYRIGHT

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