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

load_amadeus <- function(repo_path) {
  if (requireNamespace("amadeus", quietly = TRUE)) {
    return(invisible(TRUE))
  }
  if (dir.exists(repo_path) && requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(repo_path, quiet = TRUE, export_all = FALSE, helpers = FALSE)
    return(invisible(TRUE))
  }
  stop("Unable to load amadeus. Install the package or install pkgload and provide --amadeus-repo.")
}

load_amadeus(amadeus_repo)

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
