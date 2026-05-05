#!/usr/bin/env bash

set -e

cd "$(dirname "$0")/../formal"

echo "Running prove..."
sby -f noc_arbiter_prove.sby

echo "Running cover..."
sby -f noc_arbiter_cover.sby

echo "Formal runs complete."