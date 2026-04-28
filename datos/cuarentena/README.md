# Guía de Gestión de Cuarentena (Data Quality)

Este documento sirve como ayuda memoria profesional para entender los criterios de calidad aplicados al pipeline de `recetas_despachadas_2.0v`. Los registros que no cumplen con estos criterios son aislados en esta carpeta para su revisión manual y no forman parte de la capa Gold (Final).

## 🛡️ Propósito de la Cuarentena
La cuarentena asegura que la analítica final esté libre de ruidos, errores de digitación o inconsistencias lógicas que podrían sesgar los indicadores de gestión farmacéutica.

---

## 🛑 Criterios de Aislamiento

Actualmente, el sistema aplica dos reglas críticas definidas en el módulo de validación (`R/validation.R`):

### 1. Inconsistencia Temporal (Fechas)
*   **Regla:** `Fecha Despacho < Fecha Generación Receta`
*   **Descripción:** Se detectan registros donde la entrega del medicamento ocurre antes de que la receta haya sido emitida legalmente.
*   **Acción Recomendada:** 
    *   Verificar si existe un desfase de zona horaria en la captura.
    *   Revisar si el registro corresponde a una entrega adelantada por contingencia no regularizada en sistema.

### 2. Anomalía de Volumen (Dosis)
*   **Regla:** `Cantidad por Periodicidad > 1000 unidades`
*   **Descripción:** Se identifican cantidades sospechosamente altas para una sola entrega o periodo. Generalmente son errores de "dedo" (ej. tipear 10000 en vez de 100).
*   **Acción Recomendada:**
    *   Confirmar si la unidad de medida es correcta (unidades vs mg/ml).
    *   Validar con el centro emisor si la dosis es excepcional o un error de ingreso.

---

## 📈 Estructura del Archivo de Cuarentena
Cada ejecución genera un archivo `.xlsx` con el prefijo `recetas_sospechosas_[ID]`. Todos contienen la columna adicional:

*   **`motivo_cuarentena`**: Explica brevemente cuál de las reglas anteriores fue gatillada, facilitando la auditoría rápida.

---

## ⚙️ Notas Técnicas
*   Los registros en cuarentena **se descuentan** del total de la Capa Gold.
*   Si un registro cumple ambos criterios negativos, se marca como `"Fecha inconsistente y Dosis anómala"`.
*   Para modificar estos umbrales, consulte a ingeniería de datos sobre el archivo `R/validation.R`.
