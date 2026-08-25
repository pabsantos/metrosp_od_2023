# Pesquisa Origem e Destino 2023 — processed data

This repository converts the São Paulo Metropolitan Region 2023 Origin–Destination survey source files in `data-raw/` into documented, analysis-ready spatial and tabular files in `data/`. All generated text files use UTF-8, and all output variables use descriptive English `snake_case` names. Original Portuguese metadata retained for provenance is explicitly marked with a `_pt` suffix. The complete workflow is implemented in R.

## Reproduce the data

Use R 4.4 or later with the packages `dplyr`, `foreign`, `janitor`, `readr`, `readxl`, `sf`, and `tidyr`. From the repository root, run:

```sh
Rscript R/main.R
```

The pipeline creates output directories when needed and replaces its own generated files on reruns. Source files in `data-raw/` are never modified.

## R scripts

| Script | Purpose |
|---|---|
| `R/00_utils.R` | Checks dependencies and defines shared path, header-cleaning, type-conversion, and CSV-writing helpers. |
| `R/01_create_zones_geojson.R` | Reads the 527-zone shapefile, repairs invalid polygon geometry, transforms it from Córrego Alegre / UTM zone 23S (EPSG:22523) to WGS 84 (EPSG:4326), and writes GeoJSON. |
| `R/02_create_excel_csv_tables.R` | Extracts all 32 published tables and the administrative/correspondence tables, reconstructs and translates variable names, converts tables 24–30 to long OD form, validates source totals, and writes CSV files. |
| `R/03_normalize_database.R` | Maps all 147 DBF fields to descriptive English names, converts text to UTF-8, creates field/code dictionaries, and separates repeated survey records into household, family, person, and trip tables. |
| `R/main.R` | Runs the complete workflow in dependency order. |

Each processing script can also be run independently from the repository root.

## Clean data

### Spatial data

| File | Rows/features | Description |
|---|---:|---|
| `data/spatial/survey_zones.geojson` | 527 | RFC 7946 GeoJSON polygons for all 2023 survey zones. Attributes contain zone, municipality, district, and area identifiers/names. Coordinates are longitude/latitude in WGS 84. |

The source shapefile contains invalid polygon rings. The spatial script applies `sf::st_make_valid()` before transforming and exporting, and it stops if any output geometry remains invalid.

Zone identifiers align across the spatial and administrative sources. Two zone names differ in the original files and are intentionally preserved as published: zone 155 is `Cohab Jova Rural` in the shapefile and `Cohab Jova Real` in the correspondence workbook; zone 203 is `Lajeado` in the shapefile and `Lageado` in the workbook.

### Published Excel tables

| Path | Description |
|---|---|
| `data/excel/site-tables/table_1.csv` … `table_30.csv` | One CSV per sheet in `Tabelas_Site_OD2023_REV_190225.xlsx`; the sequence also includes `table_18a.csv` and `table_23a.csv`, for 32 files total. Tables 1–23a contain 527 zone rows; tables 24–30 contain 277,729 OD pairs each. |
| `data/excel/table_catalog.csv` | Catalog of every published table, including `source_sheet`, Portuguese source title (`title_pt`), English title (`title_en`), relative output filename, row count, and column count. This is the file-level data dictionary for the 32 table CSVs. |

Most published tables have one row per survey zone. Tables 24–30 are tidy, long-form origin–destination tables with exactly three variables:

| Variable | Description |
|---|---|
| `origin` | 2023 survey-zone number at the trip origin (1–527). |
| `destination` | 2023 survey-zone number at the trip destination (1–527). |
| `value` | Expanded daily trip estimate for that origin–destination pair. |

All 527 × 527 combinations are retained, including zero-valued pairs. Source workbook totals are not stored as synthetic destinations; when present, the pipeline reconciles them against the sum of the 527 destination values before writing the long table. Numeric values are preserved without display-format rounding.

### Zone correspondence and administrative tables

| File | Rows | Description |
|---|---:|---|
| `data/excel/correspondence/administrative_division.csv` | 527 | 2023 zone names, municipality and district identifiers/names, and area in hectares. |
| `data/excel/correspondence/municipalities.csv` | 39 | Number of survey zones per municipality in 2017 and 2023. |
| `data/excel/correspondence/zone_correspondence_2017_2023.csv` | 527 | Detailed mapping from 2017 zones to 2023 zones, with 2023 administrative attributes. |
| `data/excel/correspondence/zone_correspondence_pairs_2017_2023.csv` | 527 | Two-column version of the repeated-pair correspondence sheet. It is retained separately so both source worksheets have an auditable clean output. |
| `data/excel/correspondence/zoning_summary.csv` | 47 | Zone-number ranges and counts by subregion, municipality, and intra-municipal area. |

### Normalized survey database

The source DBF has one record per disclosed survey record and repeats household, family, and person attributes across trip records. The clean database is normalized using `first_household_record`, `first_family_record`, and `first_person_record`; `trip_number > 0` identifies actual trips. Identifier columns are stored as zero-padded text to preserve their documented widths. The source’s single blank household identifier is deterministically recovered from the household prefix embedded in `family_id`.

| File | Rows | Key | Description |
|---|---:|---|---|
| `data/database/households.csv` | 31,903 | `household_id` | One record per household; survey fields 1–15. |
| `data/database/families.csv` | 32,053 | `family_id` | One record per family; includes foreign key `household_id` and survey fields 16–42. |
| `data/database/persons.csv` | 79,331 | `person_id` | One record per person; includes foreign keys `household_id` and `family_id` and survey fields 43–98. |
| `data/database/trips.csv` | 112,913 | `record_id` | One record per trip (`trip_number > 0`); includes foreign keys `household_id`, `family_id`, and `person_id` and survey fields 99–147. |
| `data/database/field_dictionary.csv` | 147 | `field_number` | English `column_name`, Portuguese source variable and description (`source_variable_pt`, `description_pt`), entity assignment, source DBF name, R storage type, fixed-width positions, lengths, and Portuguese source code notes. |
| `data/database/code_dictionary.csv` | 326 | `column_name`, `code` | Normalized categorical code/Portuguese-label pairs (`label_pt`). Mappings described as “same as” another field are copied to the English alias field and retain `source_column_name` for provenance. |

Relationships between the normalized tables are:

```text
households (household_id)
  └── families (family_id, household_id)
        └── persons (person_id, family_id, household_id)
              └── trips (record_id, person_id, family_id, household_id)
```

## Validation performed by the pipeline

The scripts stop rather than silently producing partial data when an expected invariant fails. Checks include:

- exactly 527 zone features and 527 rows in every non-OD published zone table;
- exactly 277,729 unique `origin`–`destination` pairs in each of tables 24–30, with source row totals reconciled when available;
- all GeoJSON geometries valid after repair and transformed to EPSG:4326;
- exactly 147 DBF fields matching the 147 layout definitions by position;
- complete, unique English column names across every generated dataset;
- unique primary identifiers for households, families, persons, and trips; and
- complete household → family → person → trip foreign-key relationships.

## Raw sources

| Source | Used for |
|---|---|
| `data-raw/Zonas_2023.{shp,shx,dbf,prj}` | Survey-zone geometry and attributes. |
| `data-raw/Tabelas_Site_OD2023_REV_190225.xlsx` | Published zone statistics and OD matrices. |
| `data-raw/Corresp2017_2023_190225.xlsx` | Administrative divisions, municipality counts, and 2017/2023 zone correspondence. |
| `data-raw/Banco2023_divulgacao_190225.dbf` | Disclosed record-level survey database. |
| `data-raw/Layout_BD_OD2023_190225.xlsx` | Full database field definitions and categorical codes. |
| `data-raw/Lista de tabelas OD2023-190225.docx` | Original source documentation retained for reference; it is not transformed by this pipeline. |
