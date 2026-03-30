#!/usr/bin/env just --justfile

[group('help')]
[private]
default:
    @ just --list --list-heading $'justfile manual page:\n'

# show help
[group('help')]
help: default

# run assembler and link
[group('build')]
build:
    build_dir=`mktemp -d`; \
    object_file=${build_dir}main.o; \
    nasm main.asm -f elf64 -o $object_file; \
    ld $object_file -o ./bin/main

