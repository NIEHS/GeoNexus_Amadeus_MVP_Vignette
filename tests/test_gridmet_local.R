# --------------------------
# Configuration
# --------------------------

variable <- "pr"
year <- 2023


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


if (file.exists(expected_file)) {

  cat("Previous file found. Removing it...\n")

  file.remove(
    expected_file
  )

} else {

  cat("No previous file found.\n")
}


# --------------------------
# TEST 1: download_gridmet
# --------------------------

download_gridmet(
  variables = variable,
  year = year,
  directory_to_save = data_dir,
  acknowledgement = TRUE
)

pr_files <- list.files(
  pr_dir,
  pattern = "\\.nc$",
  full.names = TRUE
)

print(pr_files)

stopifnot(
  length(pr_files) > 0
)

stopifnot(
  all(file.exists(pr_files))
)

stopifnot(
  all(file.info(pr_files)$size > 0)
)

message("PASS: GridMET download test")


# --------------------------
# TEST 2: process_gridmet
# --------------------------

gridmet <- process_gridmet(
  date = c(
    "2023-01-01",
    "2023-01-10"
  ),
  variable = "Precipitation",
  path = pr_dir
)

print(gridmet)

stopifnot(
  inherits(gridmet, "SpatRaster")
)

stopifnot(
  terra::nlyr(gridmet) == 10
)

print(names(gridmet))
print(terra::time(gridmet))

message("PASS: GridMET processing test")