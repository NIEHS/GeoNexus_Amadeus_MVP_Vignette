#!/bin/sh
set -e

IMAGE=ghcr.io/niehs/geonexus-amadeus-covariate-builder:0.1.9
#IMAGE=pateldes/geonexus-amadeus-covariate-builder:0.1.9

docker buildx build --no-cache --platform linux/amd64 -t "$IMAGE" .

# Uncomment to push to registry after a successful build:
docker push "$IMAGE"

# ── Local test run ────────────────────────────────────────────────────────────
 mkdir -p test_output

docker run --rm \
  --platform linux/amd64 \
  -v $(pwd)/data:/input:ro \
  -v $(pwd)/test_output:/output \
  "$IMAGE" \
  --input-locations /input/amadeus_location_manifest.csv \
  --covariate-dataset gridmet \
  --covariate-variable tmmx \
  --start-date 2022-07-01 \
  --end-date 2022-07-07 \
  --summary-statistic mean \
  --buffer-radius-m 0
