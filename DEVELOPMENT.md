# GeoNexus + Amadeus Developer Environment

## Overview

The GeoNexus Amadeus MVP uses two repositories during development:

```text
GeoNexus_Amadeus_MVP_Vignette
        |
        | Python and R wrappers
        v
amadeus_ods
        |
        | Local Amadeus source
        v
Amadeus functions
```

The recommended local layout is to keep both repositories under the same parent directory:

```text
geo_nexus/
├── GeoNexus_Amadeus_MVP_Vignette/
│   ├── amadeus_covariate_builder.py
│   ├── amadeus_covariate_builder.R
│   ├── debug_local_amadeus.R
│   ├── data/
│   └── ...
│
└── amadeus_ods/
    ├── R/
    ├── tests/
    ├── DESCRIPTION
    ├── NAMESPACE
    └── ...
```

Keeping the repositories as siblings allows GeoNexus to reference the local Amadeus checkout with:

```text
../amadeus_ods
```

---

## 1. Clone the repositories

Create a parent directory:

```bash
mkdir -p ~/Documents/github/geo_nexus
cd ~/Documents/github/geo_nexus
```

Clone the GeoNexus MVP repository:

```bash
git clone https://github.com/NIEHS/GeoNexus_Amadeus_MVP_Vignette.git
cd GeoNexus_Amadeus_MVP_Vignette
git checkout develop
cd ..
```

Clone the Amadeus development fork:

```bash
git clone https://github.com/NIEHS/amadeus_ods.git
```

Verify the layout:

```bash
ls
```

Expected:

```text
GeoNexus_Amadeus_MVP_Vignette
amadeus_ods
```

---

## 2. Configure Amadeus Git remotes

Enter the Amadeus fork:

```bash
cd amadeus_ods
```

Check the current remotes:

```bash
git remote -v
```

The fork should normally be configured as `origin`.

Add the official Amadeus repository as `upstream`:

```bash
git remote add upstream https://github.com/NIEHS/amadeus.git
```

Verify:

```bash
git remote -v
```

Conceptually:

```text
origin
  -> NIEHS/amadeus_ods

upstream
  -> NIEHS/amadeus
```

This allows development in the fork while still syncing changes from the official Amadeus repository.

---

## 3. Install and verify R

Verify R is available:

```bash
R --version
Rscript --version
which R
which Rscript
```

The Python wrapper launches the R workflow with `Rscript`, so `Rscript` must be available from the same terminal where Python runs.

Install the R development packages:

```r
install.packages(c(
  "pkgload",
  "devtools",
  "languageserver",
  "httpgd"
))
```

Install dependencies required by the local Amadeus checkout:

```bash
cd ~/Documents/github/geo_nexus/GeoNexus_Amadeus_MVP_Vignette

Rscript -e 'devtools::install_deps("../amadeus_ods", dependencies = TRUE)'
```

---

## 4. Verify local Amadeus loading

From the GeoNexus repository:

```bash
R
```

Then:

```r
pkgload::load_all(
  "../amadeus_ods",
  reset = TRUE
)
```

Verify where Amadeus was loaded from:

```r
getNamespaceInfo(
  asNamespace("amadeus"),
  "path"
)
```

Expected result:

```text
.../geo_nexus/amadeus_ods
```

The result should not point to an installed R library such as:

```text
~/Library/R/.../library/amadeus
```

Optional version checks:

```r
packageVersion("amadeus")
packageVersion("terra")
```

---

## 5. Optional local Amadeus development helper

`debug_local_amadeus.R` can be used when working directly with Amadeus in an interactive R session.

Run:

```r
source("debug_local_amadeus.R")
```

The helper loads:

```text
../amadeus_ods
```

using `pkgload::load_all()` and prints the loaded namespace path and package versions.

This is useful for direct Amadeus development and debugging, for example:

```r
amadeus::process_gridmet(...)
```

The helper is optional when using `amadeus_covariate_builder.R` or the Python wrapper because the R wrapper can load Amadeus itself.

---

## 6. R wrapper execution modes

`amadeus_covariate_builder.R` supports two execution modes.

### Interactive development

From an R session:

```r
source("amadeus_covariate_builder.R")
```

Flow:

```text
source("amadeus_covariate_builder.R")
        |
        v
0 command-line arguments
        |
        v
interactive development configuration
```

### Python or command-line execution

The Python wrapper launches:

```text
Rscript amadeus_covariate_builder.R <10 arguments>
```

Flow:

```text
Rscript
        |
        v
10 command-line arguments
        |
        v
command-line configuration
```

Both modes use the same Amadeus workflow:

```text
                    amadeus_covariate_builder.R
                              |
                +-------------+-------------+
                |                           |
          source()                     Rscript
                |                           |
          args = 0                     args = 10
                |                           |
                v                           v
      interactive settings          Python settings
                |                           |
                +-------------+-------------+
                              |
                              v
                    Load Amadeus package
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
```

---

## 7. Local Amadeus versus installed Amadeus

During development, the R wrapper should prefer a valid local Amadeus checkout.

Recommended package-loading behavior:

```text
Is a valid amadeus_repo provided?
        |
       Yes
        |
        v
Does the directory exist and contain DESCRIPTION?
        |
       Yes
        |
        v
pkgload::load_all(amadeus_repo)
        |
        v
Use LOCAL Amadeus source


No valid local repository
        |
        v
Is Amadeus installed?
        |
       Yes
        |
        v
Use installed Amadeus package
```

Development path:

```text
../amadeus_ods
```

Installed-package fallback:

```text
R library / CRAN-installed Amadeus
```

This keeps local development and production-like execution behind the same wrapper.

---

## 8. Test the R wrapper interactively

From the GeoNexus repository:

```bash
R
```

Then:

```r
source("amadeus_covariate_builder.R")
```

The workflow should:

```text
load Amadeus
    |
    v
download source data if needed
    |
    v
process GridMET data
    |
    v
calculate covariates
    |
    v
write amadeus_extracted_raw.csv
```

When developing against `amadeus_ods`, verify the reported Amadeus namespace path points to the local repository.

---

## 9. Create the Python development environment

From the GeoNexus repository:

```bash
cd ~/Documents/github/geo_nexus/GeoNexus_Amadeus_MVP_Vignette
```

Verify Python:

```bash
python3 --version
which python3
```

Create a virtual environment:

```bash
python3 -m venv .venv
```

Activate it:

```bash
source .venv/bin/activate
```

Verify:

```bash
which python
python --version
```

The current Python wrapper uses Python standard-library modules, so no additional Python packages are required for the wrapper itself.

Verify that Python can access R:

```bash
which Rscript
Rscript --version
```

---

## 10. Run a Python dry run

Run:

```bash
python3 amadeus_covariate_builder.py \
  --amadeus-repo ../amadeus_ods \
  --dry-run
```

The dry run validates the Python-side workflow without calling R.

It should:

```text
read input CSV
    |
    v
normalize locations
    |
    v
create selected_places_centroids.csv
    |
    v
create output directories
    |
    v
write metadata and QA files
```

---

## 11. Run the complete Python workflow

Run:

```bash
python3 amadeus_covariate_builder.py \
  --amadeus-repo ../amadeus_ods
```

The complete execution flow is:

```text
amadeus_covariate_builder.py
        |
        v
read GeoNexus input CSV
        |
        v
normalize location fields
        |
        v
create selected_places_centroids.csv
        |
        v
prepare output directories
        |
        v
Rscript amadeus_covariate_builder.R
        |
        v
pass 10 command-line arguments
        |
        v
load ../amadeus_ods
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
Python reads raw extraction
        |
        v
build long output
        |
        v
build wide output
        |
        v
join original input
        |
        v
metadata + provenance + QA + logs
```

---

## 12. Output bundle

By default, the Python wrapper creates:

```text
amadeus_covariate_builder_output/
├── input/
│   ├── selected_places_centroids.csv
│   └── original input CSV
│
├── raw/
│   ├── <variable>/
│   │   └── <variable>_<year>.nc
│   ├── amadeus_extracted_raw.csv
│   └── amadeus_download_inventory.csv
│
├── derived/
│   ├── amadeus_covariates_long.csv
│   └── amadeus_covariates_wide.csv
│
├── joined/
│   └── places_amadeus_joined_features.csv
│
├── metadata/
│   ├── metadata.json
│   └── provenance.json
│
├── qa/
│   └── qa_summary.md
│
└── logs/
    └── run.log
```

The R wrapper produces the raw Amadeus extraction.

The Python wrapper organizes the complete GeoNexus output bundle.

---

## 13. VS Code development setup

Open both repositories in the same VS Code workspace:

```text
Workspace
├── GeoNexus_Amadeus_MVP_Vignette
└── amadeus_ods
```

This allows breakpoints to be placed in both the GeoNexus wrapper and Amadeus source files.

Example `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "R-Debugger",
      "request": "launch",
      "name": "Debug GeoNexus with local Amadeus",
      "debugMode": "workspace",
      "workingDirectory": "${workspaceFolder}",
      "includePackageScopes": true,
      "allowGlobalDebugging": true
    }
  ]
}
```

When debugging manually, the local Amadeus checkout can be loaded with:

```r
pkgload::load_all(
  "../amadeus_ods",
  reset = TRUE
)
```

Then run:

```r
source("amadeus_covariate_builder.R")
```

Breakpoints can be placed in:

```text
GeoNexus_Amadeus_MVP_Vignette/
    amadeus_covariate_builder.R
```

and:

```text
amadeus_ods/
    R/process.R
    R/download.R
    ...
```

---

## 14. Recommended development workflow

A normal development cycle is:

```text
Sync repositories
        |
        v
Create a development branch
        |
        v
Make changes
        |
        v
Test Amadeus function directly if needed
        |
        v
Test R wrapper interactively
        |
        v
Test Rscript execution
        |
        v
Test Python wrapper
        |
        v
Verify generated outputs
        |
        v
Commit and push changes
        |
        v
Create pull request
```

Use `amadeus_ods` for Amadeus-specific fixes.

Use `GeoNexus_Amadeus_MVP_Vignette` for GeoNexus integration, wrappers, workflow orchestration, and output handling.

The Python wrapper should remain a thin integration and orchestration layer. Geospatial implementation should remain in Amadeus.

---

## 15. Quick environment verification

From the GeoNexus repository:

```bash
ls ../amadeus_ods/DESCRIPTION

python3 --version

Rscript --version

Rscript -e \
'pkgload::load_all("../amadeus_ods", reset=TRUE); print(getNamespaceInfo(asNamespace("amadeus"), "path"))'

python3 amadeus_covariate_builder.py \
  --amadeus-repo ../amadeus_ods \
  --dry-run

python3 amadeus_covariate_builder.py \
  --amadeus-repo ../amadeus_ods
```

If all checks pass, the developer environment is ready.

---

## Architecture summary

```text
GeoNexus / Python
        |
        v
amadeus_covariate_builder.py
        |
        v
amadeus_covariate_builder.R
        |
        +------------------------------+
        |                              |
        v                              v
local ../amadeus_ods            installed Amadeus
development path                fallback path
        |                              |
        +--------------+---------------+
                       |
                       v
                  Amadeus API
                       |
                       v
        download -> process -> calculate
                       |
                       v
             extracted covariates
                       |
                       v
                GeoNexus outputs
```
