#!/bin/sh
# Builds and tests the transport-independent core with only a JDK (17+).
set -e
cd "$(dirname "$0")"
rm -rf build && mkdir -p build/core build/test
javac -Xlint:all --release 17 -d build/core $(find core/src -name '*.java')
javac --release 17 -cp build/core -d build/test $(find core/test -name '*.java')
java -cp build/core:build/test net.nearlink.core.Tests
