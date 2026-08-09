main <- function() {
  script_flags <- grep(
    "^--file=",
    commandArgs(trailingOnly = FALSE),
    value = TRUE
  )

  if (length(script_flags) != 1L) {
    stop("Could not resolve the timeline generator's script path.")
  }

  decode_rscript_argument <- function(value) {
    gsub("~+~", " ", value, fixed = TRUE)
  }

  script_path <- normalizePath(
    decode_rscript_argument(sub("^--file=", "", script_flags[[1]])),
    winslash = "/",
    mustWork = TRUE
  )
  project_root <- dirname(dirname(script_path))
  source_path <- file.path(project_root, "module02", "timeline-for-pdf.qmd")
  render_output_dir <- file.path(project_root, "_site", "module02")

  if (!requireNamespace("quarto", quietly = TRUE)) {
    stop("The quarto R package is required to render the Module 2 timeline.")
  }

  if (!file.exists(source_path)) {
    stop("Timeline source not found: ", source_path)
  }

  arguments <- vapply(
    commandArgs(trailingOnly = TRUE),
    decode_rscript_argument,
    character(1),
    USE.NAMES = FALSE
  )
  if (length(arguments) > 1L) {
    stop("Usage: Rscript scripts/make_timeline_pdf.R [output.pdf]")
  }

  if (length(arguments) == 1L) {
    output_argument <- path.expand(arguments[[1]])
    if (!grepl("^/", output_argument)) {
      output_argument <- file.path(getwd(), output_argument)
    }
    output_dir_argument <- dirname(output_argument)
    if (!dir.exists(output_dir_argument)) {
      stop("Output directory does not exist: ", output_dir_argument)
    }
    output_dir <- normalizePath(
      output_dir_argument,
      winslash = "/",
      mustWork = TRUE
    )
    output_path <- file.path(output_dir, basename(output_argument))
  } else {
    output_path <- file.path(project_root, "module02", "module02-timeline.pdf")
  }

  if (!dir.exists(dirname(output_path))) {
    stop("Output directory does not exist: ", dirname(output_path))
  }

  validate_pdf <- function(path, description) {
    details <- file.info(path)
    if (!file.exists(path) || is.na(details$size) || details$size < 1024) {
      stop(description, " is missing or too small: ", path)
    }

    connection <- file(path, open = "rb")
    on.exit(close(connection), add = TRUE)
    signature <- rawToChar(readBin(connection, what = "raw", n = 5L))
    if (!identical(signature, "%PDF-")) {
      stop(description, " does not have a valid PDF header: ", path)
    }
  }

  render_name <- basename(tempfile(
    pattern = "module02-timeline-render-",
    fileext = ".pdf"
  ))
  rendered_output <- file.path(render_output_dir, render_name)
  staged_output <- tempfile(
    pattern = paste0(".", basename(output_path), "-"),
    tmpdir = dirname(output_path),
    fileext = ".pdf"
  )

  on.exit(
    {
      if (file.exists(rendered_output)) {
        unlink(rendered_output)
      }
      if (file.exists(staged_output)) {
        unlink(staged_output)
      }
    },
    add = TRUE
  )

  quarto::quarto_render(
    input = source_path,
    output_file = render_name,
    quiet = FALSE
  )

  validate_pdf(rendered_output, "Quarto render output")

  if (!file.copy(rendered_output, staged_output, overwrite = FALSE)) {
    stop("Could not stage the rendered timeline PDF beside its destination.")
  }

  validate_pdf(staged_output, "Staged timeline PDF")

  if (!file.rename(staged_output, output_path)) {
    stop("Could not atomically replace the timeline PDF: ", output_path)
  }

  validate_pdf(output_path, "Final timeline PDF")
  cat("Rendered Module 2 timeline PDF: ", output_path, "\n", sep = "")
}

main()
