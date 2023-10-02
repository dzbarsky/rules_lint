#!/usr/bin/env bash
# Shows an end-to-end workflow for linting without failing the build
set -o errexit -o pipefail -o nounset

# Produce report files
bazel build -s --sandbox_debug //... --aspects //:lint.bzl%eslint --output_groups=diff

# Process them
find $(bazel info bazel-bin) -type f -name "*eslint.diff" | xargs patch -i
