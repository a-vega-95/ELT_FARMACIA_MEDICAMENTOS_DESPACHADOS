# =============================================================================
# CONFIGURACIÓN DEL PIPELINE - ARQUITECTURA MEDALLION (ELT)
# =============================================================================

library(targets)
library(tarchetypes)

# Configuración global
tar_option_set(
  packages = c("readr", "readxl", "dplyr", "arrow", "stringr", "lubridate", "digest", "vroom", "janitor", "here", "rlang", "uuid", "writexl"),
  error = "abridge"
)

# Cargar funciones auxiliares y módulos
source(here::here("src", "utils", "logging.R"))
modulos <- list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE)
invisible(lapply(modulos, source))

# Definición del pipeline
list(
  # 0. Monitoreo de Entradas y Trazabilidad Raíz
  tar_target(id_ejecucion, uuid::UUIDgenerate()),
  tar_target(path_diccionario, here::here("diccionario_homologacion", "diccionario_farmacia_iglobal.xlsx"), format = "file"),
  tar_target(path_datos_entrada, here::here("datos", "entrada"), format = "file"),
  
  tar_files(
    archivos_csv, 
    list.files(path_datos_entrada, pattern = "\\.csv$", full.names = TRUE, recursive = TRUE)
  ),

  # 1. CAPA BRONZE (RAW)
  tar_target(
    capa_bronze,
    {
      archivo <- archivos_csv
      nombre_base <- tools::file_path_sans_ext(basename(archivo))
      path_bronze <- here::here("datos", "bronze", paste0(nombre_base, ".parquet"))
      
      if (!dir.exists(dirname(path_bronze))) dir.create(dirname(path_bronze), recursive = TRUE)
      
      df_raw <- vroom(archivo, skip = 7, delim = ";", col_types = cols(.default = "c"), 
                      show_col_types = FALSE, .name_repair = "unique")
      
      df_raw$id_ejecucion <- id_ejecucion
      df_raw$hash_origen <- digest(archivo, file = TRUE)
      
      write_parquet(df_raw, path_bronze, compression = "snappy")
      
      list(
        path = path_bronze,
        metrics = list(filas = nrow(df_raw), hash = df_raw$hash_origen[1])
      )
    },
    pattern = map(archivos_csv),
    iteration = "list"
  ),

  # 2. CAPA SILVER (Normalized)
  tar_target(
    capa_silver,
    {
      bronze_item <- capa_bronze
      path_bronze <- bronze_item$path
      nombre_base <- tools::file_path_sans_ext(basename(path_bronze))
      path_silver <- here::here("datos", "silver", paste0(nombre_base, ".parquet"))
      
      if (!dir.exists(dirname(path_silver))) dir.create(dirname(path_silver), recursive = TRUE)
      
      df_bronze <- read_parquet(path_bronze)
      
      df_silver <- df_bronze %>%
        limpiar_nombres_columnas() %>%
        parsear_fechas_farmacia() %>%
        parsear_horas_farmacia() %>%
        estandarizar_tipos_datos()
      
      write_parquet(df_silver, path_silver, compression = "zstd")
      
      list(
        path = path_silver,
        metrics = list(filas = nrow(df_silver), n_in = bronze_item$metrics$filas)
      )
    },
    pattern = map(capa_bronze),
    iteration = "list"
  ),

  # 3. CAPA GOLD (Business)
  tar_target(
    diccionario,
    read_excel(path_diccionario) %>%
      select(1:2) %>%
      setNames(c("articulo_original", "codigo_iglobal")) %>%
      mutate(articulo_norm = str_to_upper(str_trim(articulo_original))) %>%
      group_by(articulo_norm) %>%
      summarise(codigo_iglobal = first(na.omit(codigo_iglobal)), .groups = "drop")
  ),

  tar_target(
    recetas_consolidadas_silver,
    {
      paths_silver <- sapply(capa_silver, function(x) x$path)
      df_consol <- bind_rows(lapply(paths_silver, read_parquet))
      
      timestamp <- format(Sys.time(), "%d%m%y_%H%M")
      nombre_archivo <- sprintf("recetas_despachadas_%s.parquet", timestamp)
      path_silver_timestamp <- here::here("datos", "silver", nombre_archivo)
      
      if (!dir.exists(dirname(path_silver_timestamp))) dir.create(dirname(path_silver_timestamp), recursive = TRUE)
      write_parquet(df_consol, path_silver_timestamp, compression = "zstd")
      
      df_consol
    }
  ),

  tar_target(
    capa_gold,
    {
      df_gold <- recetas_consolidadas_silver %>%
        crear_extension_17() %>%
        crear_grupos_horarios() %>%
        agregar_iso_dow() %>%
        aplicar_homologacion_iglobal(diccionario)
      
      path_final <- here::here("datos", "gold", "recetas_despachadas_consolidado.parquet")
      if (!dir.exists(dirname(path_final))) dir.create(dirname(path_final), recursive = TRUE)
      
      write_parquet(df_gold, path_final, compression = "snappy")
      
      res_audit <- detectar_alertas_dominio(df_gold, diccionario)
      
      list(
        path = path_final,
        metrics = list(
          filas = nrow(df_gold),
          nulos_iglobal = sum(is.na(df_gold$codigo_iglobal)), # Nulos por cruce
          alertas = res_audit # Contiene totales, por_fecha, por_dosis y data_cuarentena
        ),
        hash_final = calcular_hash_integridad(df_gold)
      )
    }
  ),
  
  # 4. CAPA CUARENTENA (Aislamiento de anomalías)
  tar_target(
    capa_cuarentena,
    {
      df_anomalo <- capa_gold$metrics$alertas$data_cuarentena
      
      if (nrow(df_anomalo) > 0) {
        path_cuarentena <- here::here("datos", "cuarentena", sprintf("recetas_sospechosas_%s.xlsx", str_sub(id_ejecucion, 1, 8)))
        if (!dir.exists(dirname(path_cuarentena))) dir.create(dirname(path_cuarentena), recursive = TRUE)
        
        write_xlsx(df_anomalo, path_cuarentena)
        return(path_cuarentena)
      } else {
        return(NULL)
      }
    },
    format = "file"
  ),

  # 5. REPORTE DE AUDITORIA PROFESIONAL
  tar_target(
    reporte_auditoria,
    {
      # Consolidar métricas de todas las capas
      metricas_resumen <- list(
        bronze = list(filas = sum(sapply(capa_bronze, function(x) x$metrics$filas))),
        silver = list(filas = sum(sapply(capa_silver, function(x) x$metrics$filas))),
        gold   = list(
          filas = capa_gold$metrics$filas,
          nulos_iglobal = capa_gold$metrics$nulos_iglobal,
          alertas = capa_gold$metrics$alertas,
          hash_final = capa_gold$hash_final
        ),
        quarentine_path = capa_cuarentena
      )
      
      escribir_reporte_auditoria(
        id_ejecucion = id_ejecucion,
        metricas_capas = metricas_resumen,
        path_final = capa_gold$path
      )
    },
    format = "file"
  )
)
