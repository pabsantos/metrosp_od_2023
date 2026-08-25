if (!exists("project_paths", mode = "function")) {
  source(file.path("R", "00_utils.R"), encoding = "UTF-8")
}

paths <- project_paths()
create_output_directories(paths)

site_workbook <- file.path(paths$raw, "Tabelas_Site_OD2023_REV_190225.xlsx")
correspondence_workbook <- file.path(paths$raw, "Corresp2017_2023_190225.xlsx")

read_sheet_as_text <- function(path, sheet) {
  readxl::read_excel(
    path,
    sheet = sheet,
    col_names = FALSE,
    col_types = "text",
    .name_repair = "minimal"
  )
}

is_zone_number <- function(x, maximum = 527L) {
  text <- trimws(as.character(x))
  number <- suppressWarnings(as.integer(text))
  grepl("^[0-9]+$", text) & !is.na(number) & number >= 1L & number <= maximum
}

site_name_dictionary <- c(
  zona = "zone", nome = "name", domicilios = "households", familias = "families",
  populacao = "population", matriculas_escolares = "school_enrollment", empregos = "jobs",
  automoveis_particulares = "private_cars", viagens_produzidas = "trips_produced",
  viagens_atraidas = "trips_attracted", area_ha = "area_ha", zona_de_escola = "school_zone",
  matriculas_escolares_por_tipo_de_escola_publica = "public_school_enrollment",
  particular = "private", total = "total", zona_de_emprego = "work_zone",
  empregos_por_setor_de_atividade_secundario = "secondary_sector_jobs",
  terciario = "tertiary_sector", outros = "other", empregos_por_classe_de_atividade_agricola = "agriculture_jobs",
  construcao_civil = "construction", industria = "industry", comercio = "commerce",
  servicos_transporte_de_carga = "freight_transport_services",
  transporte_de_passageiros = "passenger_transport_services",
  crediticios_financeiro = "credit_financial_services", pessoais = "personal_services",
  alimentacao = "food_services", saude = "health", educacao = "education",
  especializado = "specialized_services", administracao_publica = "public_administration",
  empregos_por_vinculo_empregaticio_assalariado_com_carteira = "formal_employee_jobs",
  assalariado_sem_carteira = "informal_employee", funcionario_publico = "public_employee",
  profissional_liberal = "independent_professional", autonomo = "self_employed",
  empregador = "employer", dono_de_negocio_familiar = "family_business_owner",
  trabalhador_familiar = "family_worker", total_de_empregos = "total_jobs",
  empregos_com_endereco_fixo_fora_da_residencia = "fixed_address_jobs_outside_home",
  na_residencia = "at_home", empregos_sem_endereco_fixo = "no_fixed_address_jobs",
  empregos_trabalho_externo = "external_work_jobs", trabalho_interno = "internal_work",
  zona_de_origem = "origin_zone", viagens_produzidas_por_modo_principal_metro = "metro",
  trem = "train", onibus = "bus", transporte_fretado = "chartered_transport",
  transporte_escolar = "school_transport", dirigindo_automovel = "car_driver",
  passageiro_de_automovel = "car_passenger", taxi_convencional = "conventional_taxi",
  taxi_nao_convencional_aplicativo = "ride_hailing", dirigindo_moto = "motorcycle_driver",
  passageiro_de_moto_e_de_mototaxi = "motorcycle_or_mototaxi_passenger",
  bicicleta = "bicycle", a_pe = "walking", viagens_produzidas_por_tipo_coletivo_a = "public_transport_a",
  individual_b = "individual_transport_b", modo_motorizado_a_b = "motorized_a_b",
  modo_nao_motorizado_c = "non_motorized_c", total_a_b_c = "total_a_b_c",
  viagens_produzidas_por_motivo_trabalho_industria = "industry_work",
  trabalho_comercio = "commerce_work", trabalho_servicos = "services_work",
  compras = "shopping", lazer = "leisure", procurar_emprego = "job_search",
  assuntos_pessoais = "personal_business", refeicao = "meal",
  viagens_produzidas_por_motivo_no_destino_trabalho_industria = "destination_industry_work",
  residencia = "home", viagens_a_pe_por_razao_da_escolha_do_modo_pequena_distancia = "short_distance",
  conducao_cara = "expensive_transport", ponto_estacao_distante = "distant_stop_or_station",
  conducao_demora_para_passar = "infrequent_transport", viagem_demorada = "long_travel_time",
  conducao_lotada = "crowded_transport", atividade_fisica = "physical_activity",
  medo_de_contagio = "fear_of_contagion", outros_motivos = "other_reasons",
  zona_de_residencia = "residence_zone", populacao_por_faixa_etaria_em_anos_ate_3 = "age_0_3",
  x4_a_6 = "age_4_6", x7_a_10 = "age_7_10", x11_a_14 = "age_11_14",
  x15_a_17 = "age_15_17", x18_a_22 = "age_18_22", x23_a_29 = "age_23_29",
  x30_a_39 = "age_30_39", x40_a_49 = "age_40_49", x50_a_59 = "age_50_59",
  x60_e_mais = "age_60_plus", tempo_medio_de_viagem_minutos_por_tipo_coletivo = "public_transport_minutes",
  individual = "individual_transport_minutes", zona_de_destino = "destination_zone",
  viagens_atraidas_por_modo_principal_metro = "metro", taxi_nao_convencional_app = "ride_hailing",
  viagens_atraidas_por_tipo_coletivo_a = "public_transport_a",
  viagens_atraidas_por_motivo_trabalho_industria = "industry_work",
  viagens_atraidas_por_motivo_no_destino_trabalho_industria = "destination_industry_work",
  populacao_por_grau_de_instrucao_nao_alfabetizado_fundamental_i_incompleto = "illiterate_or_incomplete_primary_i",
  fundamental_i_completo_fundamental_ii_incompleto = "complete_primary_i_or_incomplete_primary_ii",
  fundamental_ii_completo_medio_incompleto = "complete_primary_ii_or_incomplete_secondary",
  medio_completo_superior_incompleto = "complete_secondary_or_incomplete_higher",
  superior_completo = "complete_higher_education", populacao_por_sexo_masculino = "male",
  feminino = "female", nao_respondeu = "no_response", faixa_de_renda_ate_2_640 = "income_up_to_2640",
  x2_640_a_5_280 = "income_2640_5280", x5_280_a_10_560 = "income_5280_10560",
  x10_560_a_15_840 = "income_10560_15840", mais_de_15_840 = "income_above_15840",
  renda_total = "total_income", renda_media_familiar = "mean_family_income",
  renda_per_capita = "per_capita_income", renda_mediana_familiar = "median_family_income",
  familias_por_numero_de_automoveis_particulares_nenhum = "no_cars", x1 = "one_car",
  x2 = "two_cars", x3_ou_mais = "three_or_more_cars", total_de_familias = "total_families",
  populacao_que_trabalha_por_vinculo_empregaticio_do_primeiro_emprego_assalariado_com_carteira = "formal_employee",
  autonomo_com_cnpj = "self_employed_registered", autonomo_sem_cnpj = "self_employed_unregistered",
  populacao_por_condicao_de_atividade_ocupado = "employed", faz_bico = "casual_worker",
  em_licenca_medica = "medical_leave", aposentado = "retired", sem_trabalho = "unemployed",
  nunca_trabalhou = "never_worked", dona_de_casa = "homemaker", estudante = "student"
)

translate_site_names <- function(data, sheet) {
  missing_names <- setdiff(names(data), names(site_name_dictionary))
  if (length(missing_names) > 0L) {
    stop("Missing English names for ", sheet, ": ", paste(missing_names, collapse = ", "), call. = FALSE)
  }
  names(data) <- unname(site_name_dictionary[names(data)])
  data
}

english_table_titles <- c(
  `1` = "General Data by Survey Zone – 2023",
  `2` = "Population by Age Group and Residence Zone – 2023",
  `3` = "Population by Education Level and Residence Zone – 2023",
  `4` = "Population by Sex and Residence Zone – 2023",
  `5` = "Population by Monthly Family Income Bracket and Residence Zone – 2023",
  `6` = "Total Income, Mean Family Income, Per Capita Income, and Median Family Income by Residence Zone – 2023",
  `7` = "Families by Number of Private Cars and Residence Zone – 2023",
  `8` = "Working Population by Employment Relationship at Primary Job and Residence Zone – 2023",
  `9` = "Population by Activity Status and Residence Zone – 2023",
  `10` = "School Enrollments by Establishment Type and School Zone – 2023",
  `11` = "Jobs by Activity Sector and Work Zone – 2023",
  `12` = "Jobs by Activity Class and Work Zone – 2023",
  `13` = "Jobs by Employment Relationship and Work Zone – 2023",
  `14` = "Jobs at a Fixed Address, at Home, and Without a Fixed Address, by Work Zone – 2023",
  `15` = "Jobs with External or Internal Work by Work Zone – 2023",
  `16` = "Daily Trips Produced by Main Mode and Origin Zone – 2023",
  `17` = "Daily Trips Produced by Type and Origin Zone – 2023",
  `18` = "Daily Trips Produced by Purpose and Origin Zone – 2023",
  `18a` = "Daily Trips Produced by Destination Purpose and Origin Zone – 2023",
  `19` = "Daily Walking Trips Produced by Reason for Mode Choice and Origin Zone – 2023",
  `20` = "Average Travel Time of Trips Produced by Trip Type and Origin Zone – 2023",
  `21` = "Daily Trips Attracted by Main Mode and Destination Zone – 2023",
  `22` = "Daily Trips Attracted by Type and Destination Zone – 2023",
  `23` = "Daily Trips Attracted by Purpose and Destination Zone – 2023",
  `23a` = "Daily Trips Attracted by Destination Purpose and Destination Zone – 2023",
  `24` = "Daily Public Transport Trips by Origin and Destination Zones – 2023",
  `25` = "Daily Individual Transport Trips by Origin and Destination Zones – 2023",
  `26` = "Daily Motorized Trips by Origin and Destination Zones – 2023",
  `27` = "Daily Walking Trips by Origin and Destination Zones – 2023",
  `28` = "Daily Bicycle Trips by Origin and Destination Zones – 2023",
  `29` = "Daily Non-Motorized Trips by Origin and Destination Zones – 2023",
  `30` = "Total Daily Trips by Origin and Destination Zones – 2023"
)

site_catalog <- lapply(readxl::excel_sheets(site_workbook), function(sheet) {
  raw <- read_sheet_as_text(site_workbook, sheet)
  zone_rows <- which(is_zone_number(raw[[1]]))

  if (length(zone_rows) != 527L) {
    stop(sheet, " contains ", length(zone_rows), " zone rows; expected 527.", call. = FALSE)
  }

  first_data_row <- min(zone_rows)

  if (ncol(raw) >= 500L) {
    matrix_data <- raw[zone_rows, seq_len(528L), drop = FALSE]
    names(matrix_data) <- c("origin", paste0("destination_", seq_len(527L)))
    matrix_data <- convert_column_types(matrix_data)

    if (ncol(raw) == 529L) {
      source_total <- convert_column_types(
        data.frame(total = raw[[529L]][zone_rows], stringsAsFactors = FALSE)
      )$total
      calculated_total <- rowSums(as.data.frame(matrix_data[, -1, drop = FALSE]), na.rm = TRUE)
      if (max(abs(calculated_total - source_total), na.rm = TRUE) >= 1e-6) {
        stop("Origin-destination row totals do not reconcile for ", sheet, ".", call. = FALSE)
      }
    }

    table_data <- matrix_data |>
      tidyr::pivot_longer(
        cols = dplyr::starts_with("destination_"),
        names_to = "destination",
        names_prefix = "destination_",
        values_to = "value"
      ) |>
      dplyr::mutate(destination = as.integer(.data$destination))
  } else {
    headers <- combine_excel_headers(raw, seq.int(7L, first_data_row - 1L))
    table_data <- raw[zone_rows, , drop = FALSE]
    names(table_data) <- headers
    table_data <- table_data |>
      convert_column_types() |>
      translate_site_names(sheet)
  }

  table_number <- tolower(sub("^Tab", "", sheet, ignore.case = TRUE))
  if (!table_number %in% names(english_table_titles)) {
    stop("Missing English title for ", sheet, ".", call. = FALSE)
  }
  output_name <- paste0("table_", table_number, ".csv")
  output_path <- file.path(paths$site_tables, output_name)
  write_clean_csv(table_data, output_path)

  data.frame(
    source_sheet = sheet,
    table_number = table_number,
    title_pt = as.character(raw[[1]][2]),
    title_en = unname(english_table_titles[[table_number]]),
    file = file.path("site-tables", output_name),
    rows = nrow(table_data),
    columns = ncol(table_data),
    stringsAsFactors = FALSE
  )
}) |>
  dplyr::bind_rows()

write_clean_csv(site_catalog, file.path(paths$excel, "table_catalog.csv"))

# Administrative division by 2023 survey zone.
raw <- read_sheet_as_text(correspondence_workbook, "Divisão Administrativa")
keep <- is_zone_number(raw[[1]])
administrative_division <- raw[keep, seq_len(7L), drop = FALSE]
names(administrative_division) <- c(
  "zone_2023", "zone_name", "municipality", "municipality_name",
  "district", "district_name", "area_ha"
)
administrative_division <- convert_column_types(administrative_division)
write_clean_csv(
  administrative_division,
  file.path(paths$correspondence, "administrative_division.csv")
)

# Zone counts by municipality and survey year.
raw <- read_sheet_as_text(correspondence_workbook, "Municipios")
keep <- is_zone_number(raw[[1]], maximum = 39L)
municipalities <- raw[keep, seq_len(4L), drop = FALSE]
names(municipalities) <- c("municipality", "municipality_name", "zones_2017", "zones_2023")
municipalities <- convert_column_types(municipalities)
write_clean_csv(municipalities, file.path(paths$correspondence, "municipalities.csv"))

# Detailed 2017-to-2023 correspondence with the 2023 zone attributes.
raw <- read_sheet_as_text(correspondence_workbook, "Correspondência")
keep <- is_zone_number(raw[[2]])
zone_correspondence <- raw[keep, seq_len(8L), drop = FALSE]
names(zone_correspondence) <- c(
  "zone_2017", "zone_2023", "zone_name_2023", "municipality",
  "municipality_name", "district", "district_name", "area_ha"
)
zone_correspondence <- convert_column_types(zone_correspondence)
write_clean_csv(
  zone_correspondence,
  file.path(paths$correspondence, "zone_correspondence_2017_2023.csv")
)

# The workbook also presents the same correspondence in repeated pairs across
# the sheet. Convert that visual layout to a simple two-column table.
raw <- read_sheet_as_text(correspondence_workbook, "Correspondencia 2017 2023")
pair_starts <- seq.int(1L, ncol(raw), by = 3L)
pair_starts <- pair_starts[pair_starts + 1L <= ncol(raw)]
correspondence_pairs <- lapply(pair_starts, function(column) {
  pair <- raw[, c(column, column + 1L), drop = FALSE]
  names(pair) <- c("zone_2023", "zone_2017")
  pair[is_zone_number(pair$zone_2023), , drop = FALSE]
}) |>
  dplyr::bind_rows() |>
  convert_column_types() |>
  dplyr::arrange(.data$zone_2023)

if (nrow(correspondence_pairs) != 527L) {
  stop("The repeated-pair correspondence sheet did not produce 527 zone rows.", call. = FALSE)
}

write_clean_csv(
  correspondence_pairs,
  file.path(paths$correspondence, "zone_correspondence_pairs_2017_2023.csv")
)

# Hierarchical summary of zone ranges by subregion, municipality, and area.
raw <- read_sheet_as_text(correspondence_workbook, "Resumo")
summary_data <- raw[8:nrow(raw), seq_len(8L), drop = FALSE]
names(summary_data) <- c(
  "subregion", "municipality", "area", "first_zone_raw", "separator",
  "last_zone_raw", "zone_count", "subregion_zone_total"
)
summary_data <- summary_data |>
  dplyr::filter(nonempty_text(.data$first_zone_raw) | nonempty_text(.data$last_zone_raw)) |>
  tidyr::fill("subregion", "municipality") |>
  dplyr::mutate(
    first_zone = dplyr::coalesce(.data$first_zone_raw, .data$last_zone_raw),
    last_zone = .data$last_zone_raw
  ) |>
  dplyr::select(
    "subregion", "municipality", "area", "first_zone", "last_zone",
    "zone_count", "subregion_zone_total"
  ) |>
  convert_column_types()

write_clean_csv(summary_data, file.path(paths$correspondence, "zoning_summary.csv"))
