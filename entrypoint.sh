#!/bin/bash
set -e

# Pre-populate /output/raw from bundled demo data so R skips the network download
if [ -d /opt/gridmet_demo ]; then
    mkdir -p /output/raw
    cp -rn /opt/gridmet_demo/. /output/raw/
fi

exec python3 /app/amadeus_covariate_builder.py \
    --amadeus-repo /opt/amadeus_ods \
    --outdir /output \
    "$@"