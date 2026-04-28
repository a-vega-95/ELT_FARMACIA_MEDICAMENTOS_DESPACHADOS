library(testthat)

# Mock logger for tests
test_logger <- list(
  name = "test",
  log_file = tempfile(),
  level = "INFO"
)
log_info <- function(logger, msg) invisible(NULL)
log_warn <- function(logger, msg) invisible(NULL)
log_error <- function(logger, msg) invisible(NULL)

# Source the functions to test (assuming we are in project root)
source(here::here("R", "parsing.R"))

test_that("parsear_horas_farmacia funciona con formatos estándar", {
  df <- data.frame(
    hora_despacho = c("13:45:22", "9:05:00", "invalid", NA)
  )
  
  result <- parsear_horas_farmacia(df)
  
  expect_equal(result$hora_despacho[1], "13:45:22")
  expect_equal(result$hora_despacho[2], "9:05:00")
  expect_true(is.na(result$hora_despacho[3]))
  expect_true(is.na(result$hora_despacho[4]))
})

test_that("parsear_fechas_farmacia maneja múltiples formatos", {
  df <- data.frame(
    fecha_despacho = c("12/03/2026", "2026-03-12", "03-12-2026", ""),
    numero_rceta = 1:4,
    archivo_origen = "test.csv"
  )
  
  # Usamos un mock de aquí para que no intente escribir el log de conflictos en una ruta real si no queremos
  result <- parsear_fechas_farmacia(df, test_logger)
  
  expect_s3_class(result$fecha_despacho, "Date")
  expect_equal(as.character(result$fecha_despacho[1]), "2026-03-12")
  expect_equal(as.character(result$fecha_despacho[2]), "2026-03-12")
  expect_true(is.na(result$fecha_despacho[4]))
})
