#!/bin/sh

docker buildx build --no-cache --platform linux/amd64 -t ghcr.io/niehs/geonexus-amadeus-covariate-builder:0.1.0 .
docker push ghcr.io/niehs/geonexus-amadeus-covariate-builder:0.1.0

# mkdir -p test_output

docker run --rm \
--platform linux/amd64 \
-v $(pwd)/data:/input:ro \
-v $(pwd)/test_output:/output \
ghcr.io/niehs/geonexus-amadeus-covariate-builder:0.1.0 \
--input-locations /input/az_county_diabetes_live.csv \
--covariate-dataset gridmet \
--covariate-variable tmmx \
--start-date 2020-07-01 \
--end-date 2021-07-07