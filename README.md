# Modelo Actuarial de Tarifación (Ratemaking) – Caso PrismAuto 
**Competencia de Casos CAS 2026 (Casualty Actuarial Society)**  
**Equipo:** Los Bayesianos | **Institución:** Universidad Autónoma del Estado de México (UAEMéx)

---

## Descripción General
Este repositorio contiene el modelo actuarial integral de tarifación (*Overall Rate Indication*) desarrollado para **PrismAuto** en el marco de la **Competencia de Casos CAS 2026**. El objetivo principal del proyecto es estimar la prima pura proyectada, determinar la reserva por siniestros ocurridos pero no reportados (**IBNR**) y calcular la **tarifa indicada por exposición** para la cartera de seguros de automóviles durante el periodo de vigencia proyectado.

El flujo de trabajo abarca desde la auditoría y depuración de la base de microdatos de siniestralidad hasta la indicación tarifaria final, integrando el método *Chain-Ladder*, pruebas de hipótesis para cambios estructurales, regresiones exponenciales de frecuencia y severidad, y el cálculo del Ratio de Siniestralidad Permisible (*Permissible Loss Ratio - PLR*).

---

## Metodología y Flujo Técnico

### 1. Auditoría de Datos y Control de Calidad (`Datos`)
Se analizaron **4,620 registros** individuales de pagos parciales de siniestros ocurridos entre el `2022-T1` y el `2024-T4`. Para garantizar la integridad estadística de los triángulos de desarrollo, se implementaron tres filtros de consistencia:
* **Consistencia temporal:** Verificación de que la fecha de pago no sea anterior a la fecha de ocurrencia del siniestro ($\text{Lag} \ge 0$) (`0` exclusiones).
* **Montos negativos:** Detección de pagos parciales con valores negativos atípicos (`4` registros excluidos).
* **Siniestros catastróficos / *Outliers* (> $50,000):** Exclusión de siniestros extremos para evitar distorsiones en el desarrollo base (`4` registros excluidos).
* **Base depurada final:** **4,612 registros** válidos utilizados para la construcción de triángulos.

### 2. Desarrollo de Siniestros y Reservas (`1-Triángulo y FDD` & `Anexo2-FDD`)
* **Triángulos de Siniestralidad:** Estructuración de triángulos incrementales y acumulados por trimestre de ocurrencia y trimestre de desarrollo (12 periodos trimestrales).
* **Cambio Estructural (Prueba $t$):** Mediante pruebas $t$ de diferencia de medias entre el año 2022 y los periodos subsecuentes, se demostró evidencia estadística de un cambio operativo en la cartera tanto en **Frecuencia** ($p\text{-value} = 0.00265$) como en **Severidad** ($p\text{-value} = 0.000316$).
* **Selección de FDD y FDA:** Evaluación de promedios ponderados totales, últimos 4 periodos y **promedio ponderado de 4 periodos excluyendo máximo y mínimo** (criterio seleccionado para mitigar volatilidad), obteniendo un Factor de Desarrollo Acumulado (**FDA**) a cola de **24.4183** para el trimestre más reciente (`2024-T4`) y una reserva **IBNR** asociada de **$2,555,363.31** bajo el criterio seleccionado.

### 3. Estructura de Gastos y Ratio de Siniestralidad Permisible (`2-RSP`)
Análisis del histórico de gastos (2022–2024) sobre una prima emitida acumulada de **$1,139,032** y una exposición devengada de **2,484 unidades**, separando las erogaciones en componentes fijos y variables:
* **Gastos Variables (sobre Prima Emitida / Devengada):** Comisión y corretaje (`7.56%`), Otros gastos de adquisición (`0.52%`), Gastos generales (`3.60%`) y Licencias e impuestos (`1.68%`), sumando un gasto variable total de **13.36%**.
* **Margen de Utilidad y Contingencias:** **5.00%**.
* **Cargo Total por Gastos Fijos por Exposición:** **$50.30** (integrado por adquisición fija de `$7.48`, gastos generales fijos de `$38.89` e impuestos fijos de `$3.93`).
* **Ratio de Siniestralidad Permisible ($PLR$):**
  $$PLR = 1 - V - Q = 1 - 0.133566 - 0.0500 = 81.6434\%$$

### 4. Modelado de Tendencias de Siniestralidad (`3-Tendencia` & `Anexo3-Tendencia`)
* **Tendencia Histórica:** Ajuste de modelos de regresión exponencial sobre la prima pura trimestral (evaluando ventanas de 20, 12, 8 y 6 trimestres). Se seleccionó el ajuste de **12 puntos** (`2022-T1` a `2024-T4`), capturando una contracción anual en frecuencia de **-7.26%** y un incremento en severidad de **+10.88%**, lo que resulta en una **tendencia histórica anual de prima pura de +2.82%**.
* **Tendencia Prospectiva:** Basada en proyecciones macroeconómicas de inflación médica y vehicular (Fuente: *WTW*, periodos 2025–2027 con puntos medios de `7.5%`, `9.0%` y `11.5%`), estableciendo una **tendencia prospectiva anual seleccionada de +9.32%** (factor acumulado de **1.3212** a la fecha de proyección `31/Dic/2027`).

### 5. Indicación de Tarifa (`4-Indicación`)
Integrando los trimestres base de experiencia más recientes (`2024-T2`, `2024-T3` y `2024-T4`, con **613.05 exposiciones devengadas**) y aplicando un factor de carga por gastos de ajuste no asignados (**ULAE**) de **1.04**, se obtuvieron los siguientes resultados técnicos:

| Trimestre Ocurrencia | Exposiciones Devengadas | Siniestros Pagados ($) | FDA Seleccionado | Factor Tend. Histórica | Factor Tend. Proyectada | Factor ULAE | Siniestralidad Proyectada Total ($) | Prima Pura Proyectada ($) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **2024-T2** | 190.95 | 160,982.77 | 3.8458 | 1.0141 | 1.3212 | 1.04 | 862,686.98 | 4,517.87 |
| **2024-T3** | 221.10 | 87,800.93 | 6.2077 | 1.0070 | 1.3212 | 1.04 | 754,182.66 | 3,411.05 |
| **2024-T4** | 201.00 | 33,101.81 | 24.4183 | 1.0000 | 1.3212 | 1.04 | 1,110,640.75 | 5,525.58 |
| **Total / Promedio Ponderado** | **613.05** | **281,885.51** | — | — | — | — | **2,727,510.39** | **4,449.08** |

---

## Resumen Ejecutivo de Resultados

$$\text{Tarifa Indicada} = \frac{\text{Prima Pura Proyectada} + \text{Gasto Fijo por Exposición}}{\text{Ratio de Siniestralidad Permisible (PLR)}}$$

* **Prima Pura Proyectada Seleccionada (incluyendo ULAE):** `$4,449.08`
* **Gasto Fijo Proyectado por Exposición:** `$50.30`
* **Ratio de Siniestralidad Permisible ($PLR$):** `81.64%`
* **Tarifa Indicada Final por Exposición:** **`$5,511.03`**

---

## Estructura del Archivo (`CAS_Entrega_ver1.xlsx`)
* `Identificación`: Portada institucional y registro del equipo representativo.
* `Datos`: Base de microdatos con `4,620` registros de siniestros, variables de suscripción (potencia, antigüedad, edad, *bonus-malus*, densidad, zona geográfica) y banderas lógicas de depuración.
* `1-Triángulo y FDD`: Construcción de triángulos incrementales/acumulados y cálculo de factores *link-ratio*.
* `2-RSP`: Desglose contable de gastos fijos/variables y obtención del *Permissible Loss Ratio*.
* `3-Tendencia`: Serie histórica trimestral (`2015-T1` a `2024-T4`) y calibración de tendencias exponenciales.
* `4-Indicación`: Anexo técnico de integración actuarial y cálculo de la tarifa final indicada.
* `Anexo2-FDD` & `Anexo3-Tendencia`: Pruebas de hipótesis ($t$-test), sensibilidad de métodos de reserva IBNR y desagregación de tendencias de frecuencia/severidad.

---

## 👤 Autor
**José Carlos Estrada Barajas**  
Licenciatura en Actuaría — Universidad Autónoma del Estado de México (UAEMéx)
