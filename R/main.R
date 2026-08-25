source(file.path("R", "00_utils.R"), encoding = "UTF-8")
source(file.path("R", "01_create_zones_geojson.R"), encoding = "UTF-8")
source(file.path("R", "02_create_excel_csv_tables.R"), encoding = "UTF-8")
source(file.path("R", "03_normalize_database.R"), encoding = "UTF-8")

message("All clean data outputs were created successfully in data/.")
