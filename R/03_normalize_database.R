if (!exists("project_paths", mode = "function")) {
  source(file.path("R", "00_utils.R"), encoding = "UTF-8")
}

paths <- project_paths()
create_output_directories(paths)

database_path <- file.path(paths$raw, "Banco2023_divulgacao_190225.dbf")
layout_path <- file.path(paths$raw, "Layout_BD_OD2023_190225.xlsx")

layout <- readxl::read_excel(
  layout_path,
  sheet = "Planilha1",
  col_names = FALSE,
  col_types = "text",
  .name_repair = "minimal"
)

field_rows <- which(grepl("^[0-9]+$", trimws(as.character(layout[[1]]))))
english_field_names <- c(
  # Household fields 1-15
  "zone", "household_municipality", "household_x", "household_y", "household_id",
  "first_household_record", "household_expansion_factor", "household_number",
  "interview_code", "interview_date", "dwelling_type", "piped_water", "paved_street",
  "household_resident_count", "household_family_count",
  # Family fields 16-42
  "family_id", "first_family_record", "family_expansion_factor", "family_number",
  "family_resident_count", "housing_tenure", "bathroom_count", "domestic_employee_count",
  "car_count", "computer_count", "dishwasher_count", "single_door_refrigerator_count",
  "freezer_count", "washing_machine_count", "dvd_count", "microwave_count",
  "motorcycle_count", "clothes_dryer_count", "bicycle_count", "comfort_items_declaration",
  "brazil_economic_class", "brazil_economic_score", "car_1_year", "car_2_year",
  "car_3_year", "family_monthly_income", "family_income_code",
  # Person fields 43-98
  "person_id", "first_person_record", "person_expansion_factor", "person_number",
  "family_role", "age", "sex", "race", "currently_studies", "education_level",
  "activity_status", "individual_income_status", "individual_income",
  "stopped_transport_due_pandemic", "stopped_metro_monorail", "stopped_train",
  "stopped_bus_van", "stopped_chartered_transport", "stopped_school_transport",
  "stopped_car", "stopped_conventional_taxi", "stopped_ride_hailing",
  "stopped_motorcycle", "stopped_bicycle", "school_zone", "school_municipality",
  "school_x", "school_y", "school_type", "school_attendance_mode",
  "school_hybrid_frequency_unit", "school_hybrid_frequency", "primary_work_zone",
  "primary_work_municipality", "primary_work_x", "primary_work_y", "primary_work_at_home",
  "primary_work_external", "primary_work_occupation", "primary_work_activity_sector",
  "primary_work_employment_relationship", "primary_work_mode",
  "primary_work_hybrid_frequency_unit", "primary_work_hybrid_frequency",
  "secondary_work_zone", "secondary_work_municipality", "secondary_work_x",
  "secondary_work_y", "secondary_work_at_home", "secondary_work_external",
  "secondary_work_occupation", "secondary_work_activity_sector",
  "secondary_work_employment_relationship", "secondary_work_mode",
  "secondary_work_hybrid_frequency_unit", "secondary_work_hybrid_frequency",
  # Trip fields 99-147
  "trip_number", "trip_expansion_factor", "weekday", "person_trip_count", "origin_zone",
  "origin_municipality", "origin_x", "origin_y", "destination_zone",
  "destination_municipality", "destination_x", "destination_y", "transfer_1_zone",
  "transfer_1_municipality", "transfer_1_x", "transfer_1_y", "transfer_2_zone",
  "transfer_2_municipality", "transfer_2_x", "transfer_2_y", "transfer_3_zone",
  "transfer_3_municipality", "transfer_3_x", "transfer_3_y", "origin_purpose",
  "destination_purpose", "trip_purpose", "serve_passenger_origin",
  "serve_passenger_destination", "mode_1", "mode_2", "mode_3", "mode_4",
  "departure_hour", "departure_minute", "origin_walking_minutes", "arrival_hour",
  "arrival_minute", "destination_walking_minutes", "duration_minutes", "main_mode",
  "trip_type", "vehicle_parking_type", "vehicle_parking_cost", "walk_bicycle_reason",
  "bicycle_parking_type", "bicycle_ownership", "straight_line_distance_m", "record_id"
)

if (length(field_rows) != 147L || length(english_field_names) != length(field_rows) || anyDuplicated(english_field_names)) {
  stop("The English database field map must contain 147 unique names.", call. = FALSE)
}

fields <- data.frame(
  field_number = as.integer(layout[[1]][field_rows]),
  column_name = english_field_names,
  source_variable_pt = trimws(as.character(layout[[2]][field_rows])),
  description_pt = trimws(as.character(layout[[3]][field_rows])),
  start_position = suppressWarnings(as.integer(layout[[4]][field_rows])),
  end_position = suppressWarnings(as.integer(layout[[5]][field_rows])),
  length = suppressWarnings(as.integer(layout[[6]][field_rows])),
  source_codes_note_pt = trimws(as.character(layout[[7]][field_rows])),
  stringsAsFactors = FALSE
)
fields$entity <- cut(
  fields$field_number,
  breaks = c(0L, 15L, 42L, 98L, 147L),
  labels = c("household", "family", "person", "trip")
)
fields <- fields |>
  dplyr::select(
    "field_number", "column_name", "source_variable_pt", "description_pt", "entity",
    "start_position", "end_position", "length", "source_codes_note_pt"
  )

database <- foreign::read.dbf(database_path, as.is = TRUE)
source_dbf_names <- names(database)

if (ncol(database) != nrow(fields)) {
  stop(
    "The DBF has ", ncol(database), " fields but the layout defines ", nrow(fields), ".",
    call. = FALSE
  )
}

fields$source_dbf_name <- source_dbf_names
fields$r_storage_type <- vapply(database, function(column) class(column)[1], character(1))
names(database) <- fields$column_name

# The DBF has no encoding sidecar. Its text is Windows-1252/Latin-1; convert it
# explicitly so every generated CSV is UTF-8.
database[] <- lapply(database, function(column) {
  if (!is.character(column)) {
    return(column)
  }

  column[column %in% c("", "NULL")] <- NA_character_
  iconv(column, from = "CP1252", to = "UTF-8")
})

pad_identifier <- function(x, width) {
  text <- ifelse(
    is.na(x),
    NA_character_,
    format(x, scientific = FALSE, trim = TRUE, justify = "none")
  )
  text <- sub("[.]0+$", "", text)
  text[!nonempty_text(text)] <- NA_character_
  padding <- ifelse(is.na(text), 0L, pmax(0L, width - nchar(text)))
  ifelse(is.na(text), NA_character_, paste0(strrep("0", padding), text))
}

database$family_id <- pad_identifier(database$family_id, 9L)
database$person_id <- pad_identifier(database$person_id, 11L)
database$household_id <- pad_identifier(database$household_id, 8L)

# One source record has a blank household ID. The family identifier embeds the
# eight-character household identifier followed by the family sequence.
missing_household_id <- is.na(database$household_id) & !is.na(database$family_id)
database$household_id[missing_household_id] <- substr(database$family_id[missing_household_id], 1L, 8L)

# Extract categorical code/label pairs from the continuation rows in the source
# layout. Codes are kept as text so values such as 01 remain distinguishable.
current_field <- rep(NA_integer_, nrow(layout))
active_field <- NA_integer_
for (row in seq_len(nrow(layout))) {
  if (row %in% field_rows) {
    active_field <- as.integer(layout[[1]][row])
  }
  current_field[row] <- active_field
}

code_text <- trimws(as.character(layout[[7]]))
code_match <- regexec("^([^ ]+)\\s*[-–]\\s*(.+)$", code_text)
code_parts <- regmatches(code_text, code_match)
has_code <- lengths(code_parts) == 3L & !is.na(current_field)

codes <- data.frame(
  field_number = current_field[has_code],
  code = vapply(code_parts[has_code], `[[`, character(1), 2L),
  label_pt = vapply(code_parts[has_code], `[[`, character(1), 3L),
  stringsAsFactors = FALSE
) |>
  dplyr::left_join(
    dplyr::select(fields, "field_number", "column_name"),
    by = "field_number"
  ) |>
  dplyr::mutate(source_column_name = .data$column_name) |>
  dplyr::select("field_number", "column_name", "code", "label_pt", "source_column_name")

# Reuse source mappings where the layout says a field has the same codes as a
# previously defined field.
code_aliases <- c(
  destination_purpose = "origin_purpose",
  mode_2 = "mode_1",
  mode_3 = "mode_1",
  mode_4 = "mode_1",
  main_mode = "mode_1",
  secondary_work_activity_sector = "primary_work_activity_sector",
  secondary_work_employment_relationship = "primary_work_employment_relationship"
)

alias_codes <- lapply(names(code_aliases), function(alias) {
  source <- unname(code_aliases[[alias]])
  field_number <- fields$field_number[match(alias, fields$column_name)]
  codes |>
    dplyr::filter(.data$column_name == source) |>
    dplyr::mutate(field_number = field_number, column_name = alias)
}) |>
  dplyr::bind_rows()

codes <- dplyr::bind_rows(codes, alias_codes) |>
  dplyr::arrange(.data$field_number, .data$code)

household_columns <- fields$column_name[fields$entity == "household"]
family_columns <- fields$column_name[fields$entity == "family"]
person_columns <- fields$column_name[fields$entity == "person"]
trip_columns <- fields$column_name[fields$entity == "trip"]

households <- database |>
  dplyr::filter(.data$first_household_record == 1L) |>
  dplyr::select(dplyr::all_of(household_columns))

families <- database |>
  dplyr::filter(.data$first_family_record == 1L) |>
  dplyr::select("household_id", dplyr::all_of(family_columns))

persons <- database |>
  dplyr::filter(.data$first_person_record == 1L) |>
  dplyr::select("household_id", "family_id", dplyr::all_of(person_columns))

trips <- database |>
  dplyr::filter(.data$trip_number > 0L) |>
  dplyr::select("household_id", "family_id", "person_id", dplyr::all_of(trip_columns))

if (anyDuplicated(households$household_id)) stop("Duplicate household identifiers found.", call. = FALSE)
if (anyDuplicated(families$family_id)) stop("Duplicate family identifiers found.", call. = FALSE)
if (anyDuplicated(persons$person_id)) stop("Duplicate person identifiers found.", call. = FALSE)
if (anyDuplicated(trips$record_id)) stop("Duplicate trip record identifiers found.", call. = FALSE)

if (!all(families$household_id %in% households$household_id)) stop("A family has no matching household.", call. = FALSE)
if (!all(persons$family_id %in% families$family_id)) stop("A person has no matching family.", call. = FALSE)
if (!all(trips$person_id %in% persons$person_id)) stop("A trip has no matching person.", call. = FALSE)

write_clean_csv(fields, file.path(paths$database, "field_dictionary.csv"))
write_clean_csv(codes, file.path(paths$database, "code_dictionary.csv"))
write_clean_csv(households, file.path(paths$database, "households.csv"))
write_clean_csv(families, file.path(paths$database, "families.csv"))
write_clean_csv(persons, file.path(paths$database, "persons.csv"))
write_clean_csv(trips, file.path(paths$database, "trips.csv"))

message(
  "Normalized database: ", nrow(households), " households; ",
  nrow(families), " families; ", nrow(persons), " persons; ",
  nrow(trips), " trips."
)
