read_semester_settings <- function(path = "_semester.json") {
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

resolve_course_urls <- function(urls, settings = read_semester_settings()) {
  for (course in settings$website$navbar$right) {
    prefix <- paste0(tolower(course$text), ":")
    selected <- !is.na(urls) & startsWith(urls, prefix)
    urls[selected] <- paste0(
      sub("/$", "", course$href),
      substring(urls[selected], nchar(prefix) + 1L)
    )
  }
  urls
}
