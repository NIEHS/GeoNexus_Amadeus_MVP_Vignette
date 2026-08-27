Fix gridMET covariate processing when NetCDF layer names do not contain parseable dates

## Summary

The Amadeus covariate builder workflow fails during `process_covariates()` for gridMET NetCDF files when layer names are generated as sequential variable names such as:
air_temperature_1 air_temperature_2 air_temperature_3 ...
The current Amadeus gridMET processor expects layer names to include parseable date/day information. When those names are not present, processing fails before covariates can be calculated.



Error observed
Running:
processed <- amadeus::process_covariates

produces:


```
Cleaning daily tmmx data for year 2022...
Error in value[3L] : Error in amadeus::process_parse_ncdf_day_codes(layer_names = names(data_year), : Unable to parse gridmet layer time from: air_temperature_1, air_temperature_2, air_temperature_3, ...
Expected behavior
```
For daily gridMET files, if layer names do not contain parseable dates but the file represents a known calendar year, the processor should infer dates from layer order.

For example, for:

tmmx_2022.nc

the processor should treat:

layer 1 -> 2022-01-01 layer 2 -> 2022-01-02 layer 3 -> 2022-01-03 ...

Then it should subset the requested date range and pass the correctly named raster layers to downstream covariate calculation.
Proposed fix

Add a fallback path for gridMET processing when Amadeus cannot parse dates from NetCDF layer names.
The fallback should:

* Detect that process_covariates() failed due to unparseable gridMET layer names.
* Open the relevant gridMET NetCDF file directly with terra::rast().
* Infer daily layer dates from:

  the year in the filename, e.g. tmmx_2022.nc
  the layer position within the file

* Subset layers to the requested date range.
* Rename selected layers to ISO date strings, e.g. 2022-07-01.
* Pass the resulting raster object to calculate_covariates().

Proposed implementation in workflow wrapper

The workflow wrapper can catch the gridMET parsing error and apply a local fallback.

```R
message("Processing Amadeus covariates...") processed <- tryCatch( { amadeus::process_covariates }, error = function(e) { if (dataset_name != "gridmet") { stop(e) }
message("Amadeus gridMET parser failed; applying local NetCDF date-name fallback.")
message("Original error: ", conditionMessage(e))

if (!requireNamespace("terra", quietly = TRUE)) {
  stop("The terra package is required for the gridMET fallback processor.")
}

requested_dates <- seq(as.Date(start_date), as.Date(end_date), by = "day")
requested_years <- unique(as.integer(format(requested_dates, "%Y")))

rasters <- lapply(requested_years, function(year_value) {
  nc_path <- file.path(raw_dir, variable_name, paste0(variable_name, "_", year_value, ".nc"))
  if (!file.exists(nc_path)) {
    stop("Expected gridMET NetCDF not found: ", nc_path)
  }

  r <- terra::rast(nc_path)
  layer_dates <- seq(
    as.Date(paste0(year_value, "-01-01")),
    by = "day",
    length.out = terra::nlyr(r)
  )

  keep <- layer_dates >= as.Date(start_date) & layer_dates <= as.Date(end_date)
  if (!any(keep)) {
    return(NULL)
  }

  r <- r[[which(keep)]]
  names(r) <- format(layer_dates[keep], "%Y-%m-%d")
  r
})

rasters <- Filter(Negate(is.null), rasters)
if (!length(rasters)) {
  stop("No gridMET layers matched the requested date range.")
}

do.call(c, rasters)
} )
message("Calculating Amadeus covariates...") covars <- amadeus::calculate_covariates
```

File layout assumption

The fallback assumes gridMET NetCDF files are stored under a variable-specific directory:

raw/ tmmx/ tmmx_2022.nc

If files are instead stored directly under raw/, the fallback path should be adjusted from:

nc_path <- file.path(raw_dir, variable_name, paste0(variable_name, "_", year_value, ".nc"))
to:
nc_path <- file.path(raw_dir, paste0(variable_name, "_", year_value, ".nc"))

Acceptance criteria

Workflow can process gridmet / tmmx NetCDF files whose layers are named like air_temperature_1, air_temperature_2, etc.
Requested date range is correctly subset from the NetCDF file.
Resulting raster layers are renamed to ISO date strings.
calculate_covariates() runs successfully using the fallback-processed raster object.
Existing behavior is preserved when Amadeus can parse gridMET layer dates normally.
Non-gridMET processing errors are not swallowed by the fallback.
Missing expected NetCDF files produce a clear error message.
The fallback supports date ranges spanning more than one year.

Notes

This is intended as an MVP workflow-level fix. A longer-term fix may belong inside Amadeus itself, ideally in the gridMET processing code, so that process_covariates() can handle NetCDF files whose layer names do not encode dates.