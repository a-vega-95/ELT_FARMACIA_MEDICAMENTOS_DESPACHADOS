#' Calcula hash de integridad para un dataframe basado en las primeras columnas
#' @param df Dataframe a procesar
#' @return Hash xxHash64
calcular_hash_integridad <- function(df) {
  # Concatenar primeras 3 columnas para eficiencia
  hash_key <- paste0(df[[1]], df[[2]], if(ncol(df) >= 3) df[[3]] else "", collapse = "")
  digest::digest(hash_key, algo = "xxhash64")
}

#' Detecta alertas de dominio críticas para farmacia y extrae registros anómalos
#' @param df Dataframe procesado
#' @param diccionario Diccionario iGLOBAL (opcional para huérfanos)
#' @return Lista con conteos de alertas y subset de datos para cuarentena
detectar_alertas_dominio <- function(df, diccionario = NULL) {
  # Inicializar flags
  f_fechas <- rep(FALSE, nrow(df))
  f_dosis <- rep(FALSE, nrow(df))
  
  # 1. Fechas inconsistentes (Entrega < Prescripción)
  if ("fecha_despacho" %in% names(df) && "fecha_generacion_receta" %in% names(df)) {
    f_fechas <- !is.na(df$fecha_despacho) & !is.na(df$fecha_generacion_receta) & 
                (df$fecha_despacho < df$fecha_generacion_receta)
  }
  
  # 2. Dosis anómalas (> 1000 unidades)
  if ("cant_por_periodicidad" %in% names(df)) {
    f_dosis <- !is.na(df$cant_por_periodicidad) & (df$cant_por_periodicidad > 1000)
  }
  
  # Extraer registros para cuarentena (unión de ambos criterios)
  idx_anomalia <- which(f_fechas | f_dosis)
  df_cuarentena <- df[idx_anomalia, ]
  
  # Añadir motivo de anomalía para trazabilidad en el XLSX
  if (nrow(df_cuarentena) > 0) {
    df_cuarentena$motivo_cuarentena <- dplyr::case_when(
      f_fechas[idx_anomalia] & f_dosis[idx_anomalia] ~ "Fecha inconsistente y Dosis anómala",
      f_fechas[idx_anomalia] ~ "Fecha inconsistente (Entrega < Receta)",
      f_dosis[idx_anomalia] ~ "Dosis anómala (> 1000 unidades)",
      TRUE ~ "Otro"
    )
  }
  
  # Conteos para el log profesional
  alertas <- list(
    totales = length(idx_anomalia),
    por_fecha = sum(f_fechas),
    por_dosis = sum(f_dosis),
    data_cuarentena = df_cuarentena
  )
  
  return(alertas)
}

#' Verifica el balance de masas entre entrada y salida
#' @param n_in Filas entrada
#' @param n_out Filas salida
#' @return TRUE si el balance es correcto
verificar_balance_masas <- function(n_in, n_out) {
  return(n_in == n_out)
}
