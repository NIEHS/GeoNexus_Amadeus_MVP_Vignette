# NEXUS GeoExposure Workbench MVP Developer's Guide

## Overview

This guide and associated exemplar code are intended to provide a template and starter kit, listing the key capabilities and
interfaces of the CyVerse environment and showing how these raw materials may be used to develop a NEXUS GeoExposure Workbench MVP. This guide
proposes that GeoExposure Workbench use cases can be decomposed into tools, applications, and data collections. The GeoNexus
workbench is thus conceived as a set of interoperable tools, as asyncronous workflows and applications along with interactive notebooks
provisioned with NEXUS-specific data collections and services.

CyVerse allows the production and sharing of NEXUS-specific data collections that may be created and processed by
provisioned tools and interactive notebooks. Workbench tools and applications may be chained together into larger workflows.

The collections and tools that make up the GeoNexus workbench may be surfaced thru a bespoke GeoNexus Workbench interface,
connected to the underlying CyVerse environment via the Terrain API.

This guide provides a starter kit to create the tools, workflows, interactive applications and data collections that make up the GeoNexus workbench,
and instructs on how these components may be brought together in a custom branded GeoNexus Workbench interface.

## References

- [CyVerse Terrain API](https://cyverse-terrain.readthedocs.io/en/latest/)
- [CyVerse Workbench](https://workbench.cyverse.org/)
- [NEXUS](https://nexushub.org/)

## Developing Workbench Tools (DE Applications)

Custom NEXUS tools may be developed in any language and placed into a Docker container. This container may take custom parameters and may
ingest or produce data collections stored in CyVerse. See this CyVerse [guide](https://learning.cyverse.org/de/create_apps/#apps-vs-tools) for details.

### Design principles for NEXUS tools

NEXUS tools should perform one well-defined transformation and expose the choices that
vary between runs as configuration. Tools should not hard-code study locations, dates, or
output paths when those values can be supplied as inputs. Each tool should accept
documented inputs, validate them early, and produce predictable output collections using
stable file names and schemas. This allows a tool to run independently or be consumed by
another tool, workflow, or notebook without exposing its implementation details.

The Amadeus Covariate Builder follows this pattern. It accepts a small location manifest
and covariate parameters, runs a constrained Amadeus workflow, and returns derived tables
together with metadata, provenance, quality checks, and logs. The regular output bundle
can be inspected in the Discovery Environment or passed to a downstream CDC PLACES or
analysis workflow.

### The Amadeus vignette as an end-to-end example

The Amadeus vignette is the working example for the complete tool lifecycle:

1. Implement a small Python/R wrapper around the Amadeus package.
2. Build a container with the wrapper, R, Python, Amadeus, and geospatial dependencies.
3. Register the container as a CyVerse DE tool.
4. Create an application that maps user-facing parameters to the tool command.
5. Run the application with a CDC PLACES-derived location manifest.
6. Inspect the resulting output collection and reuse its tables in a downstream workflow.

The first demonstration should use the constrained `gridmet`/`tmmx` configuration and a
short date window. This keeps the example small enough to debug while exercising the
same input, processing, extraction, and output conventions needed by larger workflows.

After the first deployment, add screenshots of the registered tool, populated application
form, running or completed analysis, and resulting output collection.

### Coding an app and containerizing

The repository contains two cooperating wrappers:

- `amadeus_covariate_builder.py` normalizes the input CSV, creates the output bundle,
  launches R, and writes derived tables and run artifacts;
- `amadeus_covariate_builder.R` loads Amadeus, downloads or locates source data,
  processes the selected dataset, and calculates the covariates.

During local development, the GeoNexus repository is kept beside the `amadeus_ods`
checkout. The R wrapper can load that sibling checkout and fall back to an installed
Amadeus package when configured to do so. A container should make the production
dependency path explicit rather than relying on a developer's local checkout.

The container entry point should accept the same logical arguments as the local wrapper:

```text
input manifest, dataset, variable, start date, end date,
summary statistic, buffer radius, output directory, Amadeus source/version
```

The container must write all user-visible results beneath the configured output directory,
return a non-zero exit status when validation or calculation fails, and retain a run log
with the resolved command and error output. This repository documents the container
contract but does not yet contain a finalized `Dockerfile`; creating and testing the image
is a deployment task.

### Referencing as a tool in CyVerse

After the image is built and pushed to an accessible registry, create a CyVerse DE tool
definition identifying the image, command, resource requirements, and input/output
staging behavior. The tool definition should describe files and directories as data
inputs and outputs rather than embedding a developer workstation path.

The application may ultimately invoke a command equivalent to:

```bash
python3 amadeus_covariate_builder.py \
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
  --outdir amadeus_covariate_builder_output
```

Image tags, wrapper versions, and Amadeus versions belong in the provenance record so a
completed analysis can be reproduced.

### Creating an Application

An application is the user-facing configuration of the underlying tool. It should hide
implementation details while preserving the parameters that materially change the
analysis. For the MVP, the form should remain compact and use sensible defaults.

#### Mapping parameters

Map the form parameters to the wrapper arguments as follows:

| Application field | Type | Wrapper argument | Notes |
|---|---|---|---|
| Input locations | file | `--input-locations` | CDC PLACES-derived CSV |
| Location ID column | text | `--location-id-column` | Defaults to `site_id` |
| Longitude column | text | `--longitude-column` | Defaults to `lon` |
| Latitude column | text | `--latitude-column` | Defaults to `lat` |
| Covariate dataset | dropdown | `--covariate-dataset` | MVP value: `gridmet` |
| Covariate variable | dropdown | `--covariate-variable` | MVP value: `tmmx` |
| Start date | date | `--start-date` | ISO format, `YYYY-MM-DD` |
| End date | date | `--end-date` | ISO format, `YYYY-MM-DD` |
| Summary statistic | dropdown | `--summary-statistic` | MVP value: `mean` |
| Buffer radius | number | `--buffer-radius-m` | Use `0` for point extraction |
| Output collection | directory/output | `--outdir` | Contains the complete bundle |

Input files should be staged read-only where possible. The output directory should be a
new analysis collection or uniquely named subdirectory so separate runs do not overwrite
one another. An optional CDC PLACES table can be added after the core app works, using
`geoid` or `site_id` as the join key.

#### Running an analysis

Before submitting a run, confirm that the location manifest contains `site_id`, `lon`,
and `lat`, and that the selected dates and variable are supported by the image. A
successful run should expose at least:

```text
input/       normalized location manifest
raw/         downloaded inventory and extracted values
derived/     long and wide covariate tables
metadata/    metadata and provenance JSON
qa/          QA summary
logs/        run log
```

The wide table is the primary analysis-ready output. The long table preserves the
dataset, variable, date window, summary statistic, and value as explicit fields. Review
the metadata, provenance, and QA files before passing the output to another application.

Add screenshots after the DE app has been run: the populated form, analysis status,
output collection, and representative long, wide, metadata, and QA files.

## Combining Workbench Tools (Chaining Apps)

CyVerse DE applications can be composed into workflows in which the output of one
application becomes the input to another. Chaining is most useful when each application
has a clear data contract and produces a stable output collection. The workflow can then
be rerun with different input collections or parameters without changing the individual
tools.

For GeoNexus, the handoff should be explicit:

```text
CDC PLACES selection
        |
        v
selected_places_centroids.csv
        |
        v
Amadeus Covariate Builder
        |
        v
amadeus_covariates_wide.csv
        |
        v
joined or downstream analysis workflow
```

Pass collections and named files rather than assumptions about a user's local filesystem.
Each step should retain the input manifest, parameters, and provenance needed to interpret
the next step.

### CDC PLACES to Amadeus handoff

The CDC PLACES Feature Builder supplies public-health context and selection logic. It can
identify counties, tracts, ZCTAs, or other supported geographies and export a small
manifest containing geography identifiers and representative points.

The Amadeus app consumes that manifest as its location input. The minimum handoff fields
are:

```text
site_id, geo_level, geoid, state, lon, lat, selection_reason
```

The CDC PLACES feature table and Amadeus wide table can then be joined by `geoid` or
`site_id`. A typical combined row contains public-health measures followed by environmental
feature columns:

```csv
site_id,geoid,places_diabetes_crudeprev,places_obesity_crudeprev,amadeus_gridmet_tmmx_mean_20220701_20220707
az_county_001,04013,11.4,31.2,38.4
```

The manifest is the principal interface between the two apps. It prevents the Amadeus
tool from needing to know how CDC PLACES selections were made and lets the same
environmental tool be reused with another geography-selection workflow.

#### Adding interactivity

Interactive applications are appropriate when a user needs to explore data, adjust
parameters iteratively, or inspect maps and plots rather than submit one batch command.
They should still consume and produce the same documented collections as batch tools.

Potential GeoNexus interactive tools include:

- a map-based selector that displays CDC PLACES measures and exports the location manifest;
- an environmental covariate preview that displays candidate points and summarizes the
  selected date window before a full run;
- an output explorer that reads the Amadeus wide table and plots covariates by geography;
- a feature-matrix notebook that joins CDC PLACES and Amadeus outputs;
- a provenance viewer that renders metadata, parameters, QA results, and run logs.

For the MVP, an interactive notebook is a practical first target because it can read the
output collection without changing the batch extraction tool. The notebook should show
selected points, load the wide table, inspect missing values, and display joined features.

The completed guide should include screenshots showing the CDC PLACES selection or
exported manifest, the Amadeus application configuration, the resulting output collection,
and the joined data displayed in an interactive notebook.

See this CyVerse [guide](https://learning.cyverse.org/de/vice/extend_apps/) for details on interactive apps.

## Developing a GeoNexus Workbench

The Terrain API provides a programmatic interface for interacting with CyVerse services
from a custom GeoNexus interface. A branded workbench can use it to authenticate users,
discover or select data collections, submit analyses, monitor job status, and link users
to resulting collections. The custom interface is an orchestration and presentation
layer; DE tools remain responsible for validation, computation, and provenance.

A minimal integration should follow this sequence:

```text
user selects input collection and parameters
        |
        v
GeoNexus interface submits an Amadeus run through Terrain
        |
        v
interface polls job status
        |
        v
interface displays the output collection and QA status
```

The first Terrain prototype should use the existing Amadeus application rather than
reimplementing its execution logic. It should demonstrate authentication, parameter
submission, job monitoring, and a link to the output collection. Copy the exact endpoint,
request body, and authentication flow from the current Terrain API documentation and
test them against the target CyVerse environment.

Add the following after the prototype is available: a screenshot of the submission
interface, a tested request example with secrets omitted, a status response example for
success and failure, and a link from the completed run to its output collection.
