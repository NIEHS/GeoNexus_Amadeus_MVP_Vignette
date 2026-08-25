prefill <- TRUE

if (prefill) {
 
  manifest_path <- '/Users/pateldes/Documents/github/geo_nexus/GeoNexus_Amadeus_MVP_Vignette/data/selected_places_centroids.csv'
  dataset_name <- 'gridmet'
  variable_name <- 'tmmx'
  start_date <- '2020-07-01'
  end_date <- '2021-07-07'
  summary_statistic <- 'mean'
  buffer_radius_m <- '0'
  raw_dir <- '/Users/pateldes/temp/amadeus_output/raw'
  extracted_out <- '/Users/pateldes/temp/amadeus_output/raw/amadeus_extracted_raw.csv'
  amadeus_repo <- '/Users/pateldes/Documents/workspace-nexus/amadeus'
  
  
} else {

  args <- commandArgs(trailingOnly = TRUE)
  manifest_path <- args[[1]]
  dataset_name <- args[[2]]
  variable_name <- args[[3]]
  start_date <- args[[4]]
  end_date <- args[[5]]
  summary_statistic <- args[[6]]
  buffer_radius_m <- as.integer(args[[7]])
  raw_dir <- args[[8]]
  extracted_out <- args[[9]]
  amadeus_repo <- args[[10]]

}

if (requireNamespace("amadeus", quietly = TRUE)) {
  message("Using installed amadeus from: ", find.package("amadeus"))
} else if (dir.exists(amadeus_repo) && requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(amadeus_repo, quiet = TRUE, export_all = FALSE, helpers = FALSE)
  message("Using local amadeus repo from: ", amadeus_repo)
} else {
  stop("Unable to load amadeus. Install the package or install pkgload and provide --amadeus-repo.")
}

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
locs <- manifest[, c("site_id", "lon", "lat")]
start_year <- as.integer(substr(start_date, 1, 4))
end_year <- as.integer(substr(end_date, 1, 4))
if (dataset_name == "gridmet") {
  years <- c(2018, end_year);
} else {
  years <- c(start_year, end_year);
}

expected_files <- file.path(
  raw_dir,
  variable_name,
  paste0(variable_name, "_", seq(start_year, end_year), ".nc")
)

if (all(file.exists(expected_files))) {
  message("Skipping download; expected gridMET files already exist:")
  message(paste(expected_files, collapse = "\n"))
} else {
  message("Downloading Amadeus source data...")
  amadeus::download_data(
    dataset_name = dataset_name,
    year = years,
    variables = variable_name,
    directory_to_save = raw_dir,
    acknowledgement = TRUE,
    hash = FALSE
  )
}

message("Processing Amadeus covariates...")
processed <- amadeus::process_covariates(
  covariate = dataset_name,
  date = c(start_date, end_date),
  variable = variable_name,
  path = file.path(raw_dir, variable_name)
)

message("Calculating Amadeus covariates...")
covars <- amadeus::calculate_covariates(
  covariate = dataset_name,
  from = processed,
  locs = locs,
  locs_id = "site_id",
  radius = buffer_radius_m,
  fun = summary_statistic,
  geom = FALSE
)

utils::write.csv(covars, extracted_out, row.names = FALSE)
message("Amadeus namespace path: ", getNamespaceInfo("amadeus", "path"))
message("Amadeus package path: ", find.package("amadeus"))
message("Wrote extracted covariates to ", extracted_out)