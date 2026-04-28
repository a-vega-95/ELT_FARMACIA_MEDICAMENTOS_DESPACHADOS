#' Limpia los nombres de las columnas a snake_case
#' @param df Dataframe original
#' @return Dataframe con nombres limpios
limpiar_nombres_columnas <- function(df) {
  df %>% janitor::clean_names()
}

#' Estandariza tipos de datos numéricos en el reporte de farmacia
#' @param df Dataframe consolidado
#' @return Dataframe con tipos corregidos
estandarizar_tipos_datos <- function(df) {
  cols_numeric <- c(
    "n", "numero_rceta", "id_articulo_hijo", "total_recetado",
    "cant_por_periodicidad", "total_prescripciones_por_receta",
    "id_receta", "edad_anos", "edad_meses", "edad_dias"
  )
  
  for (col in cols_numeric) {
    if (col %in% names(df)) {
      # Manejar conversión de texto a número, manejando NAs implícitos
      df[[col]] <- as.numeric(df[[col]])
    }
  }
  return(df)
}
