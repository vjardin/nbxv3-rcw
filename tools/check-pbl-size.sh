#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 Free Mobile - Vincent Jardin
#
# Fail the build if an RCW+PBI image exceeds the LX2160A Service Processor's
# scratch ceiling.

set -eu

CEILING=4092    # highest size proven to boot
WARN_AT=3900    # close the to limit

if [ $# -ne 1 ]; then
	echo "usage: check-pbl-size.sh <rcw.bin>" >&2
	exit 2
fi

bin=$1
if [ ! -f "$bin" ]; then
	echo "check-pbl-size: no such file: $bin" >&2
	exit 2
fi

# `wc -c <file` gives just the count; some wc implementations pad it.
size=$(wc -c < "$bin" | tr -d ' \t')
name=${bin##*/}

if [ "$size" -gt "$CEILING" ]; then
	echo "FAIL $name: $size bytes exceeds the ${CEILING}-byte SP scratch ceiling."
	exit 1
fi

if [ "$size" -gt "$WARN_AT" ]; then
	echo "WARNING $name: $size bytes, only $((CEILING - size)) below the ${CEILING}-byte ceiling."
else
	echo "ok $name: $size bytes ($((CEILING - size)) free below the ${CEILING}-byte ceiling)"
fi
