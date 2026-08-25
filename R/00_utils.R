required_packages <- c("dplyr", "foreign", "janitor", "readr", "readxl", "sf", "tidyr")

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Install the required R packages before running the pipeline: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

project_paths <- function() {
  root <- normalizePath(getwd(), mustWork = TRUE)

  if (!dir.exists(file.path(root, "data-raw"))) {
    stop("Run the scripts from the project root (the directory containing data-raw/).", call. = FALSE)
  }

  list(
    root = root,
    raw = file.path(root, "data-raw"),
    data = file.path(root, "data"),
    spatial = file.path(root, "data", "spatial"),
    excel = file.path(root, "data", "excel"),
    site_tables = file.path(root, "data", "excel", "site-tables"),
    correspondence = file.path(root, "data", "excel", "correspondence"),
    database = file.path(root, "data", "database")
  )
}

create_output_directories <- function(paths = project_paths()) {
  dirs <- unlist(paths[c("data", "spatial", "excel", "site_tables", "correspondence", "database")])
  invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
}

nonempty_text <- function(x) {
  !is.na(x) & trimws(as.character(x)) != ""
}

combine_excel_headers <- function(raw, rows) {
  headers <- vapply(seq_len(ncol(raw)), function(column) {
    values <- as.character(unlist(raw[rows, column], use.names = FALSE))
    values <- trimws(values[nonempty_text(values)])
    paste(unique(values), collapse = " ")
  }, character(1))

  headers[headers == ""] <- paste0("column_", which(headers == ""))
  janitor::make_clean_names(headers, allow_dupes = FALSE)
}

convert_column_types <- function(data) {
  suppressMessages(
    readr::type_convert(
      data,
      col_types = readr::cols(.default = readr::col_guess()),
      na = c("", "NA", "NULL"),
      trim_ws = TRUE
    )
  )
}

write_clean_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(data, path, na = "")
  message("Wrote ", path)
  invisible(path)
}
