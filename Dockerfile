FROM rocker/geospatial:4.4

# libarchive is needed by the amadeus 'archive' R package dep — not in rocker/geospatial
RUN apt-get update \
    && apt-get install -y --no-install-recommends libarchive-dev python3 python3-pip git \
    && rm -rf /var/lib/apt/lists/*

# ── amadeus_ods ──────────────────────────────────────────────────────────────
# Clone your NIEHS fork at a pinned commit (not HEAD) for reproducibility.
# The R wrapper uses pkgload::load_all() on this path — no CRAN install needed.
ARG AMADEUS_COMMIT=main
RUN git clone https://github.com/NIEHS/amadeus_ods.git /opt/amadeus_ods \
    && cd /opt/amadeus_ods \
    && git checkout ${AMADEUS_COMMIT}

# Install pkgload + all Imports listed in amadeus_ods/DESCRIPTION
# devtools::install_deps() reads DESCRIPTION and installs deps only (not the package itself)
RUN Rscript -e '\
    install.packages(c("pkgload", "devtools", "remotes", "exactextractr", "archive", "collapse", "Rdpack")); \
    devtools::install_deps("/opt/amadeus_ods", dependencies=FALSE)'

# ── GeoNexus wrapper ─────────────────────────────────────────────────────────
COPY amadeus_covariate_builder.py /app/
COPY amadeus_covariate_builder.R  /app/
COPY data/                        /app/data/

WORKDIR /app

# CyVerse DE standard mount points
RUN mkdir -p /input /output

# amadeus_repo and outdir are baked in; all other args come from the CyVerse form
ENTRYPOINT ["python3", "/app/amadeus_covariate_builder.py", \
            "--amadeus-repo", "/opt/amadeus_ods", \
            "--outdir", "/output"]


