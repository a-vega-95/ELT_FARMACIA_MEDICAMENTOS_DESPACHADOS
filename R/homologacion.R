#' Homologar artículos con diccionario iGLOBAL
#' @param df Dataframe de recetas
#' @param diccionario Dataframe con mapeo de artículos a códigos iGLOBAL
#' @return Dataframe homologado
aplicar_homologacion_iglobal <- function(df, diccionario) {
  # Buscar la mejor columna para homologar (priorizar match exacto 'articulo')
  cols <- names(df)
  
  if ("articulo" %in% cols) {
    col_actual <- "articulo"
  } else {
    # Fallback: buscar columnas que contengan "articulo" pero ignorar las que parecen ser IDs
    matches <- which(stringr::str_detect(cols, "articulo"))
    no_id_matches <- matches[!stringr::str_detect(cols[matches], "id_")]
    
    if (length(no_id_matches) > 0) {
      col_actual <- cols[no_id_matches[1]]
    } else if (length(matches) > 0) {
      col_actual <- cols[matches[1]]
    } else {
      return(df)
    }
  }
    
    df %>%
      dplyr::mutate(articulo_norm = stringr::str_to_upper(stringr::str_trim(.data[[col_actual]]))) %>%
      dplyr::left_join(diccionario, by = "articulo_norm") %>%
      dplyr::select(-articulo_norm)
}
