# Running GeoNexus Amadeus Tests

This document describes how to run the GeoNexus Amadeus wrapper tests during local development.

## Repository layout

The recommended development layout is:

```text
geo_nexus/
├── GeoNexus_Amadeus_MVP_Vignette/
│   ├── amadeus_covariate_builder.py
│   ├── amadeus_covariate_builder.R
│   └── tests/
│       ├── test_amadeus_covariate_builder.py
│       ├── test_gridmet_local.R
│       └── TESTING.md
│
└── amadeus_ods/
    ├── R/
    ├── tests/
    ├── DESCRIPTION
    └── ...
```

Run the commands below from the root of:

```text
GeoNexus_Amadeus_MVP_Vignette
```

For example:

```bash
cd ~/Documents/github/geo_nexus/GeoNexus_Amadeus_MVP_Vignette
```

---

## Prerequisites

Verify Python:

```bash
python3 --version
```

If using a Python virtual environment, activate it:

```bash
source .venv/bin/activate
```

Verify R and `Rscript`:

```bash
R --version
Rscript --version
which Rscript
```

Verify that the local Amadeus checkout exists:

```bash
ls ../amadeus_ods/DESCRIPTION
```

The expected development layout requires:

```text
../amadeus_ods
```

to resolve to the local Amadeus repository.

---

# Python wrapper tests

The Python tests are in:

```text
tests/test_amadeus_covariate_builder.py
```

The test file contains two types of tests:

```text
Fast test
    |
    v
Python dry run
    |
    v
No R or Amadeus workflow execution


Live integration test
    |
    v
Python
    |
    v
Rscript
    |
    v
amadeus_covariate_builder.R
    |
    v
local amadeus_ods
    |
    v
GridMET / Amadeus workflow
```

## Run the normal Python tests

Run:

```bash
python3 -m unittest tests/test_amadeus_covariate_builder.py
```

The normal test run executes the dry-run test.

The live Amadeus integration test is skipped unless explicitly enabled.

Expected output is similar to:

```text
.s
----------------------------------------------------------------------
Ran 2 tests in ...

OK (skipped=1)
```

The exact order of the `.` and `s` may vary.

### What the dry-run test verifies

The dry-run test verifies that the Python wrapper can:

- read the sample input CSV
- normalize the location manifest
- create the output directory structure
- write `selected_places_centroids.csv`
- copy the source input CSV
- write metadata and provenance files
- write the QA summary
- write the run log

The dry-run test does not download GridMET data or call the R workflow.

---

## Run the live Python + R + Amadeus integration test

Set `RUN_AMADEUS_INTEGRATION=1`:

```bash
RUN_AMADEUS_INTEGRATION=1 python3 -m unittest tests/test_amadeus_covariate_builder.py
```

By default, the test expects the local Amadeus checkout at:

```text
../amadeus_ods
```

To specify the local Amadeus checkout explicitly:

```bash
AMADEUS_REPO=../amadeus_ods RUN_AMADEUS_INTEGRATION=1 python3 -m unittest tests/test_amadeus_covariate_builder.py
```

The live integration test exercises:

```text
test_amadeus_covariate_builder.py
        |
        v
amadeus_covariate_builder.py
        |
        v
Rscript
        |
        v
amadeus_covariate_builder.R
        |
        v
../amadeus_ods
        |
        v
download_data()
        |
        v
process_covariates()
        |
        v
calculate_covariates()
        |
        v
amadeus_extracted_raw.csv
        |
        v
Python derived outputs
```

### What the live integration test verifies

The live test should verify that:

- the local Amadeus repository exists
- `Rscript` is available
- the Python wrapper completes successfully
- `amadeus_extracted_raw.csv` is produced
- the long covariate output is produced
- the wide covariate output is produced
- the joined feature output is produced
- the download inventory is produced
- the run log is produced
- the extracted result contains data
- the expected `site_id`, `time`, and covariate value columns are present
- the run log confirms that the local Amadeus checkout was used

---

## Keep integration-test outputs for inspection

The tests normally use a temporary directory that is automatically removed after the test finishes.

To keep the generated output files, set `OUTPUT_DIR`.

Example:

```bash
OUTPUT_DIR=./tests/test_output AMADEUS_REPO=../amadeus_ods RUN_AMADEUS_INTEGRATION=1 python3 -m unittest tests/test_amadeus_covariate_builder.py
```

The test output will be written below:

```text
tests/
└── test_output/
    └── amadeus_output/
    ├── input/
    ├── raw/
    ├── derived/
    ├── joined/
    ├── metadata/
    ├── qa/
    └── logs/
```

This is useful when debugging a failed integration test.

---

## Run a single Python test

Run only the dry-run test:

```bash
python3 -m unittest   tests.test_amadeus_covariate_builder.TestAmadeusCovariateBuilderIntegration.test_dry_run_uses_sample_csv_and_writes_manifest_bundle
```

Run only the live integration test:

```bash
AMADEUS_REPO=../amadeus_ods RUN_AMADEUS_INTEGRATION=1 python3 -m unittest   tests.test_amadeus_covariate_builder.TestAmadeusCovariateBuilderIntegration.test_python_wrapper_runs_with_local_amadeus
```

---

# Local GridMET R integration and regression test

The R test is:

```text
tests/test_gridmet_local.R
```

This is a live integration/regression test. It uses a real GridMET NetCDF file and exercises the local Amadeus source code.

It specifically covers the two GridMET issues fixed during GeoNexus development:

1. `download_gridmet()` should safely handle a requested file that already exists.
2. `process_gridmet()` should use valid native NetCDF time metadata when GridMET layer names cannot be parsed as dates.

The test currently uses:

```text
variable = pr
year = 2023
date range = 2023-01-01 through 2023-01-10
```

The downloaded GridMET file is stored under:

```text
tests/data/gridmet/pr/pr_2023.nc
```

Because this is a live test, it requires network access when the file is downloaded.

---

## Run the GridMET R test

Run from the GeoNexus repository root:

```bash
Rscript tests/test_gridmet_local.R
```

By default, the test loads the sibling local Amadeus checkout:

```text
../amadeus_ods
```

The test uses `pkgload::load_all()` and verifies that the loaded Amadeus namespace points to the local checkout instead of an installed R-library copy.

Expected startup output is similar to:

```text
Loading local Amadeus from:
.../geo_nexus/amadeus_ods

Amadeus loaded from:
.../geo_nexus/amadeus_ods
```

---

## Use a different local Amadeus checkout

The test supports the `AMADEUS_REPO` environment variable.

For example:

```bash
AMADEUS_REPO=/absolute/path/to/amadeus_ods Rscript tests/test_gridmet_local.R
```

If `AMADEUS_REPO` is not supplied, the test defaults to:

```text
../amadeus_ods
```

This allows another developer to run the test without editing the R file.

---

## What `test_gridmet_local.R` tests

The R test is organized into four stages.

### Test 1: Fresh GridMET download

The test first removes an existing:

```text
tests/data/gridmet/pr/pr_2023.nc
```

if one is present.

It then runs:

```r
amadeus::download_gridmet(
  variables = "pr",
  year = 2023,
  directory_to_save = data_dir,
  acknowledgement = TRUE
)
```

The test verifies that the expected NetCDF file exists and that the downloaded file is not empty.

```text
remove old pr_2023.nc if present
        |
        v
download_gridmet()
        |
        v
pr_2023.nc created
        |
        v
verify file exists and size > 0
```

Expected completion message:

```text
PASS: Fresh GridMET download test
```

Because Test 1 intentionally removes the previous file, this R test performs a fresh GridMET download each time it runs. This is intentional because the test verifies the real download path before testing existing-file reuse.

---

### Test 2: Existing GridMET file reuse

After Test 1 finishes, `pr_2023.nc` already exists.

The test calls `download_gridmet()` again without deleting the file:

```r
amadeus::download_gridmet(
  variables = "pr",
  year = 2023,
  directory_to_save = data_dir,
  acknowledgement = TRUE
)
```

This is a regression test for the previous failure:

```text
No URLs provided for download
```

The expected behavior is:

```text
pr_2023.nc already exists
        |
        v
download_gridmet() checks requested files
        |
        v
no new download is required
        |
        v
function returns normally
```

The test confirms that the existing file remains present and non-empty.

Expected completion message:

```text
PASS: Existing GridMET file reuse test
```

---

### Test 3: Native NetCDF time metadata

The test opens the downloaded file directly with `terra`:

```r
raw_gridmet <- terra::rast(expected_file)
```

It then reads:

```r
raw_time <- terra::time(raw_gridmet)
```

The test verifies that:

- the object is a `SpatRaster`
- it contains raster layers
- the number of time values matches the number of raster layers
- the time metadata is not entirely missing

This confirms that the GridMET NetCDF file already contains usable date information even when its layer names look like:

```text
precipitation_amount_1
precipitation_amount_2
precipitation_amount_3
...
```

Conceptually:

```text
GridMET NetCDF
        |
        +--> layer names:
        |      precipitation_amount_1
        |      precipitation_amount_2
        |      ...
        |
        +--> native time metadata:
               2023-01-01
               2023-01-02
               ...
```

Expected completion message:

```text
PASS: Raw GridMET time metadata test
```

---

### Test 4: `process_gridmet()` date processing

The final test calls:

```r
gridmet <- amadeus::process_gridmet(
  date = c(
    "2023-01-01",
    "2023-01-10"
  ),
  variable = "Precipitation",
  path = pr_dir
)
```

The test verifies that:

- the returned object is a `SpatRaster`
- exactly 10 daily layers are returned
- 10 time values are returned
- the first date is `2023-01-01`
- the last date is `2023-01-10`

This is the regression test for GridMET files whose layer names are not directly parseable as dates but whose native `terra::time()` metadata is valid.

Expected completion message:

```text
PASS: GridMET processing test
```

If every R test passes, the script ends with:

```text
ALL GRIDMET LOCAL TESTS PASSED
```

---

## Debug the R test interactively

For step-by-step debugging, start R from the GeoNexus repository root:

```bash
R
```

Load the local Amadeus source:

```r
pkgload::load_all(
  "../amadeus_ods",
  reset = TRUE
)
```

Verify the namespace:

```r
getNamespaceInfo(
  asNamespace("amadeus"),
  "path"
)
```

The path should point to:

```text
.../geo_nexus/amadeus_ods
```

Then run:

```r
source("tests/test_gridmet_local.R")
```

When using the VS Code R debugger, breakpoints can also be placed in:

```text
../amadeus_ods/R/download.R
../amadeus_ods/R/process.R
```

---

## Generated GridMET test data

The R test creates real downloaded data below:

```text
tests/data/gridmet/
```

For example:

```text
tests/
└── data/
    └── gridmet/
        └── pr/
            └── pr_2023.nc
```

These files are generated test artifacts and should not be committed to Git.

Add this to `.gitignore`:

```gitignore
tests/data/gridmet/
```

---

# Recommended test order

During normal development, run tests in this order:

```text
1. Python dry-run test
        |
        v
2. Local GridMET R test
        |
        v
3. Python live integration test
```

Commands:

```bash
python3 -m unittest tests/test_amadeus_covariate_builder.py

Rscript tests/test_gridmet_local.R

AMADEUS_REPO=../amadeus_ods RUN_AMADEUS_INTEGRATION=1 python3 -m unittest tests/test_amadeus_covariate_builder.py
```

This sequence separates failures by layer:

```text
Python dry run fails
    -> Python wrapper / manifest / output setup issue

GridMET R test fails
    -> Amadeus / R / GridMET issue

Live integration test fails
    -> Python-to-R integration or end-to-end workflow issue
```

---

# Troubleshooting

## Rscript not found

Check:

```bash
which Rscript
Rscript --version
```

If `Rscript` cannot be found, the Python integration test cannot launch the R wrapper.

## Local Amadeus repository not found

Check:

```bash
ls ../amadeus_ods/DESCRIPTION
```

Or specify the path explicitly:

```bash
AMADEUS_REPO=/absolute/path/to/amadeus_ods RUN_AMADEUS_INTEGRATION=1 python3 -m unittest tests/test_amadeus_covariate_builder.py
```

## Installed Amadeus is used instead of local Amadeus

Inspect:

```text
<test output>/amadeus_output/logs/run.log
```

The log should contain a message similar to:

```text
Using local amadeus repo from: .../amadeus_ods
```

and the namespace path should point to the local checkout.

## Live test downloads data

The integration test may download GridMET files if the required files do not already exist in the selected test output directory.

This is expected for a live integration test.

Use the fast dry-run test for routine Python development when a live download is not needed.

---

# Quick commands

Normal Python test:

```bash
python3 -m unittest tests/test_amadeus_covariate_builder.py
```

Local GridMET R test:

```bash
Rscript tests/test_gridmet_local.R
```

Full Python + R + local Amadeus integration test:

```bash
AMADEUS_REPO=../amadeus_ods RUN_AMADEUS_INTEGRATION=1 python3 -m unittest tests/test_amadeus_covariate_builder.py
```

Full integration test with preserved output:

```bash
OUTPUT_DIR=./tests/test_output AMADEUS_REPO=../amadeus_ods RUN_AMADEUS_INTEGRATION=1 python3 -m unittest tests/test_amadeus_covariate_builder.py
```
