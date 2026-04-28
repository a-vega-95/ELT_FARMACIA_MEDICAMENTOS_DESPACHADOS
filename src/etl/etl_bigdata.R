# =============================================================================
# ETL BIG DATA - RECETAS DESPACHADAS HOMOLOGACIÓN
# =============================================================================
# Procesamiento optimizado y modularizado
# =============================================================================

library(readr)
library(readxl)
library(dplyr)
library(arrow)
library(stringr)
library(lubridate)
library(digest)
library(vroom)
library(janitor)

# Instalar/cargar here para rutas robustas
if (!require("here", quietly = TRUE)) install.packages("here")
library(here)

# Logger y Módulos
source(here("src", "utils", "logging.R"))
modulos <- list.files(here("R"), pattern = "\\.R$", full.names = TRUE)
invisible(lapply(modulos, source))

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

INPUT_DIR <- here("datos_entrada")
OUTPUT_DIR <- here("datos_salida")
DICT_FILE <- here("diccionario_homologacion", "diccionario_farmacia_iglobal.xlsx")
OUTPUT_FILE <- "recetas_despachadas_consolidado.parquet"

PARQUET_CONFIG <- list(
  row_group_size = 10000,
  compression = "snappy",
  use_dictionary = TRUE
)

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  ETL MODULAR - RECETAS DESPACHADAS\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat(sprintf("Inicio: %s\n", Sys.time()))

logger <- init_logger("etl")
log_info(logger, "Inicio ETL MODULAR")

# =============================================================================
# PASO 0: VALIDACIONES DE DIRECTORIOS
# =============================================================================

if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)
if (!dir.exists(INPUT_DIR)) {
  dir.create(INPUT_DIR, recursive = TRUE)
  log_error(logger, "Carpeta datos_entrada no existe. Creada vacía.")
  stop("Coloque archivos CSV en datos_entrada/ y reinicie.")
}

# =============================================================================
# PASO 1: CARGAR DICCIONARIO
# =============================================================================

cat("1. Cargando diccionario de homologación...\n")
diccionario <- read_excel(DICT_FILE) %>%
  select(1:2) %>%
  setNames(c("articulo_original", "codigo_iglobal")) %>%
  mutate(articulo_norm = str_to_upper(str_trim(articulo_original))) %>%
  group_by(articulo_norm) %>%
  summarise(codigo_iglobal = first(na.omit(codigo_iglobal)), .groups = "drop")

# =============================================================================
# PASO 2: LISTAR ARCHIVOS
# =============================================================================

archivos <- list.files(INPUT_DIR, pattern = "\\.csv$", full.names = TRUE)
if (length(archivos) == 0) stop("No se encontraron archivos CSV.")

# =============================================================================
# PASO 3: PROCESAMIENTO MODULAR (LOOP)
# =============================================================================

cat(sprintf("2. Procesando %d archivos...\n", length(archivos)))
all_data <- list()
total_registros <- 0
hashes_originales <- list()

for (i in seq_along(archivos)) {
  archivo <- archivos[i]
  nombre <- basename(archivo)
  
  tryCatch({
    df <- vroom(archivo, skip = 7, delim = ";", col_types = cols(.default = "c"), 
                show_col_types = FALSE, .name_repair = "unique") %>%
      limpiar_nombres_columnas()
    
    registros <- nrow(df)
    total_registros <- total_registros + registros
    
    file_hash <- calcular_hash_integridad(df)
    hashes_originales[[i]] <- list(archivo = nombre, hash = file_hash, registros = registros)
    
    df$archivo_origen <- nombre
    all_data[[i]] <- df
    
    cat(sprintf("   [%d/%d] %s (%s registros)\n", i, length(archivos), nombre, format(registros, big.mark = ",")))
  }, error = function(e) {
    log_error(logger, sprintf("Error en %s: %s", nombre, e$message))
  })
}

# =============================================================================
# PASO 4: CONSOLIDACIÓN Y NORMALIZACIÓN (Uso de módulos R/)
# =============================================================================

cat("\n3. Consolidando y normalizando (Módulos R)...\n")
df_consolidado <- bind_rows(all_data)

df_consolidado <- df_consolidado %>%
  parsear_fechas_farmacia(logger) %>%
  parsear_horas_farmacia() %>%
  crear_extension_17(logger) %>%
  crear_grupos_horarios(logger) %>%
  agregar_iso_dow(logger) %>%
  estandarizar_tipos_datos()

# =============================================================================
# PASO 5: HOMOLOGACIÓN
# =============================================================================

cat("4. Aplicando homologación IGLOBAL...\n")
col_articulo <- names(df_consolidado)[str_detect(names(df_consolidado), "articulo")][1]

if (!is.na(col_articulo)) {
  df_consolidado <- df_consolidado %>%
    mutate(articulo_norm = str_to_upper(str_trim(.data[[col_articulo]]))) %>%
    left_join(diccionario, by = "articulo_norm") %>%
    select(-articulo_norm)
  
  homologados <- sum(!is.na(df_consolidado$codigo_iglobal))
  log_info(logger, sprintf("Homologación: %d registrados", homologados))
}

# =============================================================================
# PASO 6: VALIDACIÓN Y SALIDA
# =============================================================================

cat("5. Validando integridad y guardando Parquet...\n")
hash_consolidado <- calcular_hash_integridad(df_consolidado)
output_path <- file.path(OUTPUT_DIR, OUTPUT_FILE)

write_parquet(df_consolidado, output_path, 
              compression = PARQUET_CONFIG$compression,
              use_dictionary = PARQUET_CONFIG$use_dictionary,
              chunk_size = PARQUET_CONFIG$row_group_size)

# Balance de masas modular
verificar_balance_masas(total_registros, nrow(df_consolidado), nrow(read_parquet(output_path, as_data_frame = FALSE)), logger)

# =============================================================================
# REPORTE FINAL
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  REPORTE FINAL (MODULAR)\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat(sprintf("Registros procesados: %s\n", format(nrow(df_consolidado), big.mark = ",")))
cat(sprintf("Columnas finales: %d\n", ncol(df_consolidado)))
cat(sprintf("Salida: %s\n", basename(output_path)))
cat(sprintf("Hash final: %s\n", substr(hash_consolidado, 1, 16)))
cat(sprintf("Fin: %s\n", Sys.time()))
cat("═══════════════════════════════════════════════════════════════\n\n")
