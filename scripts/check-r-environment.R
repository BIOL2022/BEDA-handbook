lock <- renv::lockfile_read("renv.lock")
if (!identical(as.character(getRversion()), lock$R$Version)) {
  stop("Use R ", lock$R$Version, " to match renv.lock.", call. = FALSE)
}
packages <- names(lock$Packages)
incorrect <- Filter(function(name) {
  !requireNamespace(name, quietly = TRUE) ||
    packageVersion(name) != package_version(lock$Packages[[name]]$Version)
}, packages)
if (length(incorrect)) {
  stop("Run renv::restore() to restore these locked packages: ",
       paste(incorrect, collapse = ", "), call. = FALSE)
}
cat("R and all ", length(packages), " locked packages match renv.lock.\n", sep = "")
