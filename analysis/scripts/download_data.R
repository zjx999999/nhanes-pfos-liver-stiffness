args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("^--file=", "", args[grepl("^--file=", args)][1])
phase_root <- normalizePath(file.path(dirname(script_arg), ".."), mustWork = TRUE)
manifest_path <- file.path(phase_root, "reproducibility", "data_manifest.csv")
data_root <- Sys.getenv("NHANES_DATA_ROOT", unset = file.path(phase_root, "input_data"))
manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)

sha256_file <- function(path) {
  result <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
  status <- attr(result, "status")
  if (length(result) == 0L || (!is.null(status) && status %in% c(1L, 127L))) stop("shasum failed for: ", path)
  sub("  .*", "", result[1])
}

for (i in seq_len(nrow(manifest))) {
  dest <- file.path(data_root, manifest$local_relative_path[i])
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(dest) && identical(sha256_file(dest), manifest$sha256[i])) {
    message("Verified existing: ", manifest$file[i])
    next
  }
  tmp <- paste0(dest, ".download")
  status <- download.file(manifest$source_url[i], tmp, mode = "wb", quiet = FALSE)
  if (status != 0L || file.info(tmp)$size != manifest$bytes[i] || !identical(sha256_file(tmp), manifest$sha256[i])) {
    unlink(tmp)
    stop("Download size or SHA-256 verification failed: ", manifest$file[i])
  }
  if (file.exists(dest)) unlink(dest)
  if (!file.rename(tmp, dest)) stop("Could not move verified download into place: ", dest)
  message("Downloaded and verified: ", manifest$file[i])
}
cat("All", nrow(manifest), "CDC NHANES files are present and match SHA-256.\n")
