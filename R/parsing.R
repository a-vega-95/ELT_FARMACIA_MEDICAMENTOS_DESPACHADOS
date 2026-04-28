#' Normaliza fechas con soporte multiformato
#' @param df Dataframe consolidado
#' @return Dataframe con fechas normalizadas
parsear_fechas_farmacia <- function(df) {
  columnas_fecha <- c(
    "fecha_generacion_receta",
    "fecha_vigencia_receta",
    "fecha_despacho",
    "fecha_proximo_despacho",
    "fecha_de_nacimiento",
    "fecha_vencimiento",
    "fecha_despacho_domicilio"
  )
  
  for (col in columnas_fecha) {
    if (col %in% names(df)) {
      # Convertir vacíos y valores centinela conocidos a NA real antes de parsear
      valores_limpiar <- c("", " ", "ADSCRITOS-INFO NO DISPONIBLE")
      df[[col]][df[[col]] %in% valores_limpiar] <- NA
      
      # Intentar parseo multiformato
      df[[col]] <- as.Date(lubridate::parse_date_time(df[[col]], orders = c("dmy", "mdy", "ymd", "d-m-Y"), quiet = TRUE))
    }
  }
  
  return(df)
}

#' Normaliza horas extrayendo formato HH:MM:SS
#' @param df Dataframe consolidado
#' @return Dataframe con horas normalizadas
parsear_horas_farmacia <- function(df) {
  columnas_hora <- c(
    "hora_generacion_receta",
    "hora_despacho",
    "hora_despacho_domicilio"
  )
  
  for (col in columnas_hora) {
    if (col %in% names(df)) {
      df[[col]] <- stringr::str_extract(df[[col]], "\\d{1,2}:\\d{2}:\\d{2}")
    }
  }
  return(df)
}
