# ============================================================
# GeoNexus + Local Amadeus Development Environment
# https://github.com/NIEHS/GeoNexus_Amadeus_MVP_Vignette 
# https://github.com/NIEHS/amadeus_ods
#
# Both the repos should be under same parent directory, e.g., Projects

#  - Projects
#    - GEONEXUS
#         amadeus_covariate_builder.R
#         ...

#     - AMADEUS
#         R/
#             process.R
#             download.R
#             ...
#         tests/
#         DESCRIPTION
# ============================================================

cat("\nLoading LOCAL Amadeus source...\n")

amadeus_path <- normalizePath(
  "../amadeus_ods"
)

cat("Amadeus source path:\n")
print(amadeus_path)


# Load local source package
pkgload::load_all(
  amadeus_path,
  reset = TRUE
)


# Verify where R loaded Amadeus from
loaded_path <- getNamespaceInfo(
  asNamespace("amadeus"),
  "path"
)

cat("\nAmadeus loaded from:\n")
print(loaded_path)


cat("\nAmadeus version:\n")
print(
  packageVersion("amadeus")
)


cat("\nTerra version:\n")
print(
  packageVersion("terra")
)


cat("\nLOCAL AMADEUS DEVELOPMENT ENVIRONMENT READY\n")
