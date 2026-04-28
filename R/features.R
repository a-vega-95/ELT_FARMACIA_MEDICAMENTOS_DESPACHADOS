#' Crea el flag de horario extendido (>= 17:00)
#' @param df Dataframe consolidado
#' @return Dataframe con columna extension_17
crear_extension_17 <- function(df) {
  if ("hora_despacho" %in% names(df)) {
    df <- df %>%
      dplyr::mutate(
        hora_despacho_decimal = as.numeric(sub(":.*", "", `hora_despacho`)),
        extension_17 = dplyr::if_else(hora_despacho_decimal >= 17, "SI", "NO", missing = "NO")
      ) %>%
      dplyr::select(-hora_despacho_decimal)
  }
  return(df)
}

#' Crea grupos horarios de bloques de 1 hora
#' @param df Dataframe consolidado
#' @return Dataframe con columna grupo_horas
crear_grupos_horarios <- function(df) {
  if ("hora_despacho" %in% names(df)) {
    df <- df %>%
      dplyr::mutate(
        hora_despacho_num = as.numeric(sub(":.*", "", `hora_despacho`)),
        grupo_horas = sprintf("%02d:00-%02d:59", hora_despacho_num, hora_despacho_num)
      ) %>%
      dplyr::select(-hora_despacho_num)
  }
  return(df)
}

#' Agrega el día de la semana ISO (1-7)
#' @param df Dataframe consolidado
#' @return Dataframe con columna iso_dow
agregar_iso_dow <- function(df) {
  if ("fecha_despacho" %in% names(df)) {
    df <- df %>%
      dplyr::mutate(
        iso_dow = as.integer(strftime(`fecha_despacho`, format = "%u"))
      )
  }
  return(df)
}
