# MVP: Port Amadeus Covariate Builder to CyVerse Discovery Environment

## Objective

Package a constrained Amadeus workflow as a CyVerse Discovery Environment app that accepts a small set of study locations derived from CDC PLACES geographies and generates environmental covariates for those locations.

This MVP should demonstrate a realistic but limited Geo Workbench workflow, not a full production port of all Amadeus functionality.

## Conceptual link to prior CDC PLACES task

The prior CDC PLACES Feature Builder app generates area-level public-health context features, such as diabetes, obesity, asthma, or smoking prevalence by county, tract, ZCTA, or other geography.

The Amadeus DE app should extend that pattern by using the same selected geographies, or representative points derived from them, to calculate environmental covariates.

The linked vignette is:

```text
CDC PLACES Feature Builder
  → identify public-health context variables of interest
  → select geographies or study areas of interest
  → export a geography/location manifest
  → run Amadeus Covariate Builder in CyVerse DE
  → generate environmental covariates for the same areas
  → produce a joined contextual + environmental feature matrix
```

This creates the first two-app Geo Workbench demonstration pattern:

```text
public-health context features
  → selected geographies
  → environmental covariate generation
  → reusable joined feature table
```

## Why this matters

This app demonstrates that CyVerse Discovery Environment can support R-based environmental covariate workflows and compose outputs across multiple Geo Workbench apps.

Amadeus is a strong fit because it provides an R workflow for accessing and analyzing large-scale environmental data using a staged pattern:

```text
download_data()
  → process_covariates()
  → calculate_covariates()
```

For this MVP, the goal is to expose one constrained Amadeus workflow through CyVerse DE and produce reusable covariate outputs with metadata, provenance, QA, and logs.

## MVP definition of done

A user can run the Amadeus DE app with a small CSV of locations derived from CDC PLACES-selected geographies and receive:

- Amadeus-derived environmental covariates for each location
- a long-format covariate table
- a wide-format analysis-ready feature matrix
- metadata and provenance files
- a QA summary
- a run log
- optionally, a joined CDC PLACES + Amadeus feature table

---

## Recommended MVP vignette

### Vignette: CDC PLACES health context plus Amadeus environmental covariates

1. Run the CDC PLACES Feature Builder app for a small geography, such as Arizona counties.
2. Select geographies with public-health context variables of interest, such as high diabetes, obesity, smoking, or asthma prevalence.
3. Export a location manifest containing GEOIDs and representative points.
4. Run the Amadeus Covariate Builder app in CyVerse DE.
5. Select one environmental dataset and variable for a short time window.
6. Generate environmental covariates for the selected locations.
7. Produce a reusable joined feature matrix.

Example final joined output:

```csv
site_id,geo_level,geoid,state,places_diabetes_crudeprev,places_obesity_crudeprev,amadeus_gridmet_tmmx_mean_20220701_20220707
az_county_001,county,04013,AZ,11.4,31.2,38.4
az_county_002,county,04019,AZ,10.9,29.8,37.9
```

---

## MVP scope

### In scope

- Package a constrained Amadeus workflow as a CyVerse DE app.
- Use a small point/centroid-based location manifest as input.
- Support one environmental dataset and a small number of variables.
- Support a short date range for demonstration.
- Produce long-format and wide-format covariate outputs.
- Produce metadata, provenance, QA, and logs.
- Optionally join Amadeus outputs to a CDC PLACES wide feature table.
- Provide a short demo walkthrough showing the CDC PLACES to Amadeus sequence.

### Out of scope for MVP

- Full support for all Amadeus datasets.
- Full national-scale processing.
- Polygon-based zonal summaries.
- Automated derivation of centroids from TIGER/Line or other boundary services.
- Interactive visualization dashboard.
- Production API caching.
- Restricted or individual-level data.
- Full ontology mapping.
- GA4GH Passport/DUO-based authorization.
- Dockstore/TRS registration.
- Complex geometry processing.

---

## Key design decision

For the first sprint, this should be a point/centroid-based covariate extraction app, not a full polygon-summary app.

This keeps the CyVerse DE app realistic, minimizes geometry complexity, and directly exercises the core Amadeus pattern:

```text
input locations
  → retrieve or process environmental source data
  → calculate covariates
  → produce reusable feature table
```

Polygon summaries can be added as a follow-on issue after the app is running reliably in CyVerse DE.

---

## CDC PLACES to Amadeus handoff manifest

The CDC PLACES app, or a small helper script, should produce a location manifest that can be passed directly to the Amadeus app.

### Recommended input file

```text
selected_places_centroids.csv
```

### MVP schema

| Field | Type | Required | Description |
|---|---|---:|---|
| `site_id` | string | yes | Study site or selected geography identifier |
| `geo_level` | string | yes | Geography level, such as `county`, `tract`, or `zcta` |
| `geoid` | string | yes | Standard geography identifier |
| `state` | string | yes | State abbreviation |
| `lon` | number | yes | Longitude of representative point |
| `lat` | number | yes | Latitude of representative point |
| `selection_reason` | string | no | Why this geography was selected from CDC PLACES |

### Example

```csv
site_id,geo_level,geoid,state,lon,lat,selection_reason
az_county_001,county,04013,AZ,-112.491,33.348,high_diabetes_prevalence
az_county_002,county,04019,AZ,-111.789,32.097,high_obesity_prevalence
```

---

## MVP CyVerse DE user form parameters

The DE form should remain compact and demo-friendly.

| Parameter | Type | Required | MVP default | Notes |
|---|---|---:|---|---|
| `input_locations` | file input | yes | `selected_places_centroids.csv` | CSV with location IDs and coordinates |
| `location_id_column` | text | yes | `site_id` | Column containing unique location IDs |
| `longitude_column` | text | yes | `lon` | Longitude column |
| `latitude_column` | text | yes | `lat` | Latitude column |
| `covariate_dataset` | dropdown | yes | `gridmet` | Use one supported dataset for MVP |
| `covariate_variable` | dropdown | yes | `tmmx` | Example: maximum temperature |
| `start_date` | date | yes | `2022-07-01` | Start of covariate window |
| `end_date` | date | yes | `2022-07-07` | Short demo window |
| `summary_statistic` | dropdown | yes | `mean` | MVP can support only mean |
| `buffer_radius_m` | number | no | `0` | Use point extraction for MVP |
| `cdc_places_wide_table` | file input | no | none | Optional table to join by `geoid` or `site_id` |
| `output_prefix` | text | no | `amadeus_demo` | Used to name output files |

### Example MVP command

```bash
Rscript amadeus_covariate_builder.R \
  --input-locations selected_places_centroids.csv \
  --location-id-column site_id \
  --longitude-column lon \
  --latitude-column lat \
  --covariate-dataset gridmet \
  --covariate-variable tmmx \
  --start-date 2022-07-01 \
  --end-date 2022-07-07 \
  --summary-statistic mean \
  --buffer-radius-m 0 \
  --outdir "${OUTPUT_DIR}"
```

---

## MVP output bundle

Each successful run should produce a predictable output folder:

```text
amadeus_covariate_builder_output/
  input/
    selected_places_centroids.csv
  raw/
    amadeus_download_inventory.csv
  derived/
    amadeus_covariates_long.csv
    amadeus_covariates_wide.csv
    amadeus_feature_dictionary.csv
  joined/
    places_amadeus_joined_features.csv
  metadata/
    metadata.json
    provenance.json
  qa/
    qa_summary.md
  logs/
    run.log
```

The `joined/` folder is optional for MVP but should be included if a CDC PLACES wide feature table is provided as an input.

---

## MVP output schema: long-format Amadeus covariate table

### File

```text
derived/amadeus_covariates_long.csv
```

### Purpose

The long table preserves one row per location, dataset, variable, date or time window, and summary statistic.

### Required MVP fields

| Field | Type | Required | Description |
|---|---|---:|---|
| `site_id` | string | yes | Input location or study site identifier |
| `geo_level` | string | no | Geography level from CDC PLACES handoff manifest |
| `geoid` | string | no | Standard geography identifier |
| `state` | string | no | State abbreviation |
| `covariate_dataset` | string | yes | Amadeus dataset name |
| `covariate_variable` | string | yes | Environmental variable |
| `start_date` | date | yes | Start of requested window |
| `end_date` | date | yes | End of requested window |
| `summary_statistic` | string | yes | Example: `mean` |
| `value` | number | yes | Calculated covariate value |
| `unit` | string | no | Unit, if available |
| `buffer_radius_m` | number | no | Buffer radius used for extraction; `0` for point extraction |
| `workflow_name` | string | yes | `amadeus-covariate-builder` |
| `workflow_version` | string | yes | App or workflow version |
| `provenance_id` | string | yes | Identifier linking row to run provenance |

### Example

```csv
site_id,geo_level,geoid,state,covariate_dataset,covariate_variable,start_date,end_date,summary_statistic,value,unit,buffer_radius_m,workflow_name,workflow_version,provenance_id
az_county_001,county,04013,AZ,gridmet,tmmx,2022-07-01,2022-07-07,mean,38.4,C,0,amadeus-covariate-builder,0.1.0,run_20260715_000002
az_county_002,county,04019,AZ,gridmet,tmmx,2022-07-01,2022-07-07,mean,37.9,C,0,amadeus-covariate-builder,0.1.0,run_20260715_000002
```

---

## MVP output schema: wide Amadeus feature matrix

### File

```text
derived/amadeus_covariates_wide.csv
```

### Purpose

The wide table is the main analysis-ready Amadeus output. It should contain one row per location and one feature column per selected covariate.

### Required MVP fields

| Field | Type | Required | Description |
|---|---|---:|---|
| `site_id` | string | yes | Input location or study site identifier |
| `geo_level` | string | no | Geography level |
| `geoid` | string | no | Standard geography identifier |
| `state` | string | no | State abbreviation |
| `amadeus_<dataset>_<variable>_<summary>_<start>_<end>` | number | yes | Generated environmental feature column |

### Feature naming convention

```text
amadeus_<dataset>_<variable>_<summary>_<yyyymmdd_start>_<yyyymmdd_end>
```

Example:

```text
amadeus_gridmet_tmmx_mean_20220701_20220707
```

---

## Optional joined output: CDC PLACES plus Amadeus

### File

```text
joined/places_amadeus_joined_features.csv
```

### Purpose

If the user provides a CDC PLACES wide feature table, the app can join it with the Amadeus wide covariate matrix using `geoid` or `site_id`.

### Example

```csv
site_id,geo_level,geoid,state,places_diabetes_crudeprev,places_obesity_crudeprev,amadeus_gridmet_tmmx_mean_20220701_20220707
az_county_001,county,04013,AZ,11.4,31.2,38.4
az_county_002,county,04019,AZ,10.9,29.8,37.9
```

---

## MVP metadata and provenance

### Metadata file

```text
metadata/metadata.json
```

Minimum fields:

```json
{
  "source_package": "amadeus",
  "workflow_name": "amadeus-covariate-builder",
  "workflow_version": "0.1.0",
  "covariate_dataset": "gridmet",
  "covariate_variable": "tmmx",
  "start_date": "2022-07-01",
  "end_date": "2022-07-07",
  "summary_statistic": "mean",
  "input_locations": "input/selected_places_centroids.csv",
  "retrieved_at": "2026-07-15T00:00:00Z"
}
```

### Provenance file

```text
metadata/provenance.json
```

Minimum fields:

```json
{
  "provenance_id": "run_YYYYMMDD_HHMMSS",
  "workflow_name": "amadeus-covariate-builder",
  "workflow_version": "0.1.0",
  "container_image": "amadeus-covariate-builder:0.1.0",
  "command": "Rscript amadeus_covariate_builder.R ...",
  "status": "success",
  "inputs": {
    "input_locations": "selected_places_centroids.csv",
    "covariate_dataset": "gridmet",
    "covariate_variable": "tmmx",
    "start_date": "2022-07-01",
    "end_date": "2022-07-07",
    "summary_statistic": "mean"
  },
  "outputs": [
    "derived/amadeus_covariates_long.csv",
    "derived/amadeus_covariates_wide.csv",
    "derived/amadeus_feature_dictionary.csv",
    "metadata/metadata.json",
    "metadata/provenance.json",
    "qa/qa_summary.md",
    "logs/run.log"
  ]
}
```

---

## MVP QA summary

### File

```text
qa/qa_summary.md
```

The QA summary should include:

- number of input locations
- number of successful covariate calculations
- number of failed or missing covariate calculations
- selected dataset
- selected variable
- requested date window
- output file inventory
- overall run status

Example:

```markdown
# Amadeus Covariate Builder QA Summary

## Run summary

- Dataset: `gridmet`
- Variable: `tmmx`
- Date window: `2022-07-01` to `2022-07-07`
- Input locations: 2
- Summary statistic: `mean`

## Checks

| Check | Result |
|---|---|
| Input locations loaded | PASS |
| Environmental data retrieved or located | PASS |
| Covariates calculated | PASS |
| Long covariate table produced | PASS |
| Wide covariate matrix produced | PASS |
| Metadata file produced | PASS |
| Provenance file produced | PASS |
```

---

## Implementation tasks

- [ ] Review Amadeus functions and identify one reliable MVP dataset-variable combination.
- [ ] Define CDC PLACES to Amadeus handoff manifest.
- [ ] Create a small demo location manifest derived from CDC PLACES-selected geographies.
- [ ] Create R command-line wrapper around the selected Amadeus workflow.
- [ ] Expose explicit CLI arguments for input file, coordinate columns, dataset, variable, date range, and output directory.
- [ ] Implement long-format Amadeus covariate output.
- [ ] Implement wide-format Amadeus feature matrix.
- [ ] Generate Amadeus feature dictionary.
- [ ] Generate `metadata.json`.
- [ ] Generate `provenance.json`.
- [ ] Generate `qa_summary.md`.
- [ ] Add structured run logging.
- [ ] Create Dockerfile or container recipe with Amadeus and geospatial dependencies.
- [ ] Test workflow locally with MVP parameters.
- [ ] Package workflow as CyVerse DE app.
- [ ] Run at least one demo job in CyVerse DE.
- [ ] Document the CDC PLACES to Amadeus demo flow.

---

## Acceptance criteria

- [ ] User can launch the Amadeus Covariate Builder from CyVerse DE.
- [ ] User can provide a location manifest with `site_id`, `lon`, and `lat`.
- [ ] User can select a constrained dataset, variable, date window, and summary statistic.
- [ ] App runs successfully using a small demo configuration.
- [ ] App produces raw or inventory, derived, metadata, QA, and log folders.
- [ ] Long-format covariate table follows the MVP schema.
- [ ] Wide-format feature matrix follows the MVP schema.
- [ ] Metadata and provenance files are generated for every run.
- [ ] QA summary reports basic validation checks.
- [ ] Outputs can be joined to CDC PLACES outputs by `geoid` or `site_id`.
- [ ] README or demo notes explain how to run the app and interpret outputs.

---

## Future enhancements

After the MVP is working, create follow-on issues for:

- add polygon-based zonal summaries
- add support for additional Amadeus datasets
- add support for additional variables and summary statistics
- add direct derivation of centroids from GEOIDs
- add TIGER/Line or staged boundary support
- add optional geometry-aware outputs such as GeoJSON or GeoPackage
- add richer QA reports
- add visualization outputs
- add caching for repeated environmental data requests
- add ontology or ECTO mapping placeholders
- add Dockstore/TRS workflow publication
- add integration with downstream ExWAS workflows