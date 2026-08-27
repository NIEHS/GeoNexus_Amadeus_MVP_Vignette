# ============================================================
# Local GridMET integration/regression test
#
# Tests:
#   1. GridMET file can be downloaded
#   2. Existing GridMET file can be reused without error
#   3. GridMET NetCDF time metadata is processed correctly
#
# Run from GeoNexus repository root:
#
#   Rscript tests/test_gridmet_local.R
#
# Optional:
#
#   AMADEUS_REPO=/path/to/amadeus_ods \
#   Rscript tests/test_gridmet_local.R
# ============================================================

# --------------------------
# Load local Amadeus
# --------------------------

amadeus_repo <- Sys.getenv(
  "AMADEUS_REPO",
  unset = "../amadeus_ods"
)

amadeus_repo <- normalizePath(
  amadeus_repo,
  mustWork = TRUE
)

stopifnot(
  file.exists(
    file.path(
      amadeus_repo,
      "DESCRIPTION"
    )
  )
)

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop(
    "pkgload is required to run this test."
  )
}

cat("Loading local Amadeus from:\n")
print(amadeus_repo)

pkgload::load_all(
  amadeus_repo,
  reset = TRUE,
  quiet = TRUE,
  export_all = FALSE,
  helpers = FALSE
)


# Verify that the local checkout is loaded

loaded_path <- getNamespaceInfo(
  asNamespace("amadeus"),
  "path"
)

cat("Amadeus loaded from:\n")
print(loaded_path)

stopifnot(
  normalizePath(loaded_path) ==
    normalizePath(amadeus_repo)
)


# --------------------------
# Configuration
# --------------------------

variable <- "pr"
year <- 2023

start_date <- "2023-01-01"
end_date <- "2023-01-10"

# Store test data inside this GeoNexus project.
data_dir <- file.path(
  getwd(),
  "tests",
  "data",
  "gridmet"
)

cat("Data directory:\n")
print(data_dir)


# Create directory
dir.create(
  data_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

stopifnot(
  dir.exists(data_dir)
)

# clean previous test data
pr_dir <- file.path(
  data_dir,
  variable
)

expected_file <- file.path(
  pr_dir,
  paste0(
    variable,
    "_",
    year,
    ".nc"
  )
)

cat("Expected GridMET file:\n")
print(expected_file)

# ============================================================
# TEST 1: Fresh GridMET download
# ============================================================

if (file.exists(expected_file)) {

  message(
    "Removing previous GridMET file for fresh-download test."
  )

  removed <- file.remove(
    expected_file
  )

  stopifnot(
    removed
  )
}


message(
  "TEST 1: Downloading fresh GridMET file..."
)

amadeus::download_gridmet(
  variables = variable,
  year = year,
  directory_to_save = data_dir,
  acknowledgement = TRUE
)


stopifnot(
  file.exists(expected_file)
)

stopifnot(
  file.info(expected_file)$size > 0
)


message(
  "PASS: Fresh GridMET download test"
)


# ============================================================
# TEST 2: Existing GridMET file reuse
#
# Regression test for:
# download_gridmet() previously calling download_run_method()
# with an empty URL list when all files already existed.
# ============================================================

message(
  "TEST 2: Re-running download with existing file..."
)


# Do NOT delete expected_file here.
#
# The test passes if download_gridmet() returns without the
# "No URLs provided for download" error.

amadeus::download_gridmet(
  variables = variable,
  year = year,
  directory_to_save = data_dir,
  acknowledgement = TRUE
)


stopifnot(
  file.exists(expected_file)
)

stopifnot(
  file.info(expected_file)$size > 0
)


message(
  "PASS: Existing GridMET file reuse test"
)


# ============================================================
# TEST 3: Verify native NetCDF time metadata
# ============================================================

message(
  "TEST 3: Inspecting raw GridMET NetCDF time metadata..."
)


raw_gridmet <- terra::rast(
  expected_file
)


stopifnot(
  inherits(
    raw_gridmet,
    "SpatRaster"
  )
)

stopifnot(
  terra::nlyr(raw_gridmet) > 0
)


raw_time <- terra::time(
  raw_gridmet
)

stopifnot(
  length(raw_time) ==
    terra::nlyr(raw_gridmet)
)

stopifnot(
  !all(is.na(raw_time))
)


cat(
  "First raw GridMET dates:\n"
)

print(
  head(raw_time)
)


message(
  "PASS: Raw GridMET time metadata test"
)


# ============================================================
# TEST 4: process_gridmet
#
# Regression test for GridMET layer names such as:
#
#   precipitation_amount_1
#   precipitation_amount_2
#
# when valid dates are already available through terra::time().
# ============================================================

message(
  "TEST 4: Processing GridMET data..."
)


gridmet <- amadeus::process_gridmet(
  date = c(
    start_date,
    end_date
  ),
  variable = "Precipitation",
  path = pr_dir
)


print(
  gridmet
)


stopifnot(
  inherits(
    gridmet,
    "SpatRaster"
  )
)


# Jan 1 through Jan 10 = 10 daily layers

stopifnot(
  terra::nlyr(gridmet) == 10
)


processed_time <- terra::time(
  gridmet
)


stopifnot(
  length(processed_time) == 10
)

stopifnot(
  as.Date(processed_time[[1]]) ==
    as.Date(start_date)
)

stopifnot(
  as.Date(processed_time[[10]]) ==
    as.Date(end_date)
)


cat(
  "Processed layer names:\n"
)

print(
  names(gridmet)
)


cat(
  "Processed dates:\n"
)

print(
  processed_time
)


message(
  "PASS: GridMET processing test"
)


message(
  "ALL GRIDMET LOCAL TESTS PASSED"
)
message("PASS: GridMET processing test")