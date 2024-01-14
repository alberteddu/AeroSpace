#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

# ./build-debug.sh || exit 125 # `git bisect run` compatible
xcodebuild -scheme AeroSpace test

./run-cli.sh -h
./run-cli.sh -v
