prefill <- TRUE

if (prefill) {
 
  manifest_path <- '/Users/conwaymc/temp/amadeus_output/input/selected_places_centroids.csv'
  dataset_name <- 'gridmet'
  variable_name <- 'tmmx'
  start_date <- '2022-07-01'
  end_date <- '2023-07-07'
  summary_statistic <- 'mean'
  buffer_radius_m <- '0'
  raw_dir <- '/Users/conwaymc/temp/amadeus_output/raw'
  extracted_out <- '/Users/conwaymc/temp/amadeus_output/raw/amadeus_extracted_raw.csv'
  amadeus_repo <- '/Users/conwaymc/Documents/workspace-nexus/amadeus'
  
  
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

if (!requireNamespace("amadeus", quietly = TRUE)) {
  if (dir.exists(amadeus_repo) && requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(amadeus_repo, quiet = TRUE, export_all = FALSE, helpers = FALSE)
  } else {
    stop("Unable to load amadeus. Install the package or install pkgload and provide --amadeus-repo.")
  }
}

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
locs <- manifest[, c("site_id", "lon", "lat")]
years <- c(as.integer(substr(start_date, 1, 4)), as.integer(substr(end_date, 1, 4)))

message("Downloading Amadeus source data...")
amadeus::download_data(
  dataset_name = dataset_name,
  year = years,
  variable = variable_name,
  directory_to_save = raw_dir,
  acknowledgement = TRUE,
  hash = FALSE
)

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
message("Wrote extracted covariates to ", extracted_out)
