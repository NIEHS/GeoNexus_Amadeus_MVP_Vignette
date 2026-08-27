# ============================================================
# GeoNexus + Local Amadeus Development Environment
#
# GeoNexus:
# https://github.com/NIEHS/GeoNexus_Amadeus_MVP_Vignette
#
# Local Amadeus fork:
# https://github.com/NIEHS/amadeus_ods
#
# Recommended directory layout:
#
# geo_nexus/
# ├── GeoNexus_Amadeus_MVP_Vignette/
# │   ├── amadeus_covariate_builder.R
# │   ├── amadeus_covariate_builder.py
# │   └── debug_local_amadeus.R
# │
# └── amadeus_ods/
#     ├── R/
#     ├── tests/
#     ├── DESCRIPTION
#     └── ...
#
# Run from the GeoNexus repository root:
#
#   source("debug_local_amadeus.R")
#
# Optional override:
#
#   Sys.setenv(AMADEUS_REPO = "/path/to/amadeus_ods")
#   source("debug_local_amadeus.R")
# ============================================================


cat("\nLoading LOCAL Amadeus source...\n")


# ------------------------------------------------------------
# Resolve local Amadeus repository
# ------------------------------------------------------------

amadeus_path <- Sys.getenv(
  "AMADEUS_REPO",
  unset = "../amadeus_ods"
)

amadeus_path <- normalizePath(
  amadeus_path,
  mustWork = TRUE
)


# Verify this looks like an R package

if (!file.exists(file.path(amadeus_path, "DESCRIPTION"))) {
  stop(
    "Invalid Amadeus repository. DESCRIPTION not found at: ",
    amadeus_path
  )
}


cat("\nAmadeus source path:\n")
print(amadeus_path)


# ------------------------------------------------------------
# Verify pkgload
# ------------------------------------------------------------

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop(
    "pkgload is required. Install it with install.packages('pkgload')."
  )
}


# ------------------------------------------------------------
# Load local source package
# ------------------------------------------------------------

pkgload::load_all(
  amadeus_path,
  reset = TRUE,
  quiet = TRUE,
  export_all = FALSE,
  helpers = FALSE
)


# ------------------------------------------------------------
# Verify loaded namespace
# ------------------------------------------------------------

loaded_path <- getNamespaceInfo(
  asNamespace("amadeus"),
  "path"
)

cat("\nAmadeus loaded from:\n")
print(loaded_path)


if (
  normalizePath(loaded_path) !=
  normalizePath(amadeus_path)
) {
  stop(
    "Amadeus was not loaded from the expected local repository."
  )
}


# ------------------------------------------------------------
# Versions
# ------------------------------------------------------------

cat("\nAmadeus version:\n")
print(
  packageVersion("amadeus")
)

cat("\nTerra version:\n")
print(
  packageVersion("terra")
)


cat("\nLOCAL AMADEUS DEVELOPMENT ENVIRONMENT READY\n")