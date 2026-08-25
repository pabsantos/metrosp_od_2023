if (!exists("project_paths", mode = "function")) {
  source(file.path("R", "00_utils.R"), encoding = "UTF-8")
}

paths <- project_paths()
create_output_directories(paths)

source_shapefile <- file.path(paths$raw, "Zonas_2023.shp")
output_geojson <- file.path(paths$spatial, "survey_zones.geojson")

zones <- sf::st_read(
  source_shapefile,
  quiet = TRUE,
  options = "ENCODING=LATIN1"
)

names(zones) <- janitor::make_clean_names(names(zones), allow_dupes = FALSE)
names(zones)[match(
  c("numero_zona", "nome_zona", "numero_muni", "nome_munici", "num_distrit", "nome_distri", "area_ha_2"),
  names(zones)
)] <- c(
  "zone", "zone_name", "municipality", "municipality_name",
  "district", "district_name", "area_ha"
)

if (is.na(sf::st_crs(zones))) {
  stop("The survey-zone shapefile does not have a defined coordinate reference system.", call. = FALSE)
}

# GeoJSON uses WGS 84 longitude/latitude. Repairing the source polygons before
# transformation prevents invalid rings from producing invalid GeoJSON geometry.
zones <- zones |>
  sf::st_make_valid() |>
  sf::st_transform(4326) |>
  dplyr::arrange(.data$zone)

if (any(!sf::st_is_valid(zones))) {
  stop("One or more survey-zone geometries remain invalid after repair.", call. = FALSE)
}

sf::st_write(
  zones,
  output_geojson,
  driver = "GeoJSON",
  delete_dsn = TRUE,
  layer_options = c("RFC7946=YES", "COORDINATE_PRECISION=15", "WRITE_BBOX=YES"),
  quiet = TRUE
)

written_zones <- sf::st_read(output_geojson, quiet = TRUE)
if (nrow(written_zones) != nrow(zones) || any(!sf::st_is_valid(written_zones))) {
  stop("The written GeoJSON failed round-trip feature-count or geometry validation.", call. = FALSE)
}

message("Wrote ", output_geojson, " (", nrow(zones), " zones; EPSG:4326)")
