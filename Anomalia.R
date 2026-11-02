library(readxl)
library(tidyverse)
library(lubridate)
library(naniar)      
library(robustbase) 
library(moments)
library(writexl)

datos_crudos <- read_excel("C:/Users/Carlos Estrada/Desktop/CAS/Datos_crudos.xlsx")

d <- datos_crudos %>%
  rename(id = `ID PrismAuto`, ns = `Numero de siniestros`,
         pot = `Potencia del vehículo`, ant = `Antigüedad del vehículo`,
         edad = `Edad del conductor`, bm = `Bonificación-penalización`,
         marca = `Marca del vehículo`, comb = Combustible, area = Área,
         dens = `Densidad de la ciudad`, fa = `Fecha del accidente`,
         ciudad = Ciudad, pago = `Pago parcial`, fp = `Fecha de pago`) %>%
  mutate(fa = as.Date(fa), fp = as.Date(fp),
         lag = as.numeric(fp - fa))

fecha_eval <- max(d$fp)


# ---- Granularidad ----

cat("\n--- A. Granularidad ---\n")
cat("Filas (pagos):", nrow(d), "\n")
cat("Polizas unicas (id):", n_distinct(d$id), "\n")
cat("Siniestros unicos (id, fa):", nrow(distinct(d, id, fa)), "\n")

# Pagos por siniestro
pagos_x_sin <- d %>% count(id, fa, name = "n_pagos")
print(table(pagos_x_sin$n_pagos))

# Siniestros por poliza
sin_x_pol <- d %>% group_by(id) %>%
  summarise(ns = first(ns), n_fa = n_distinct(fa), n_filas = n())
print(table(sin_x_pol$ns, sin_x_pol$n_fa))

# Si ns == n_fa en casi todas las polizas => "Numero de siniestros" es un
# atributo de POLIZA repetido en cada pago, NO el conteo de filas.

cat("% polizas donde ns == siniestros distintos:",
    round(mean(sin_x_pol$ns == sin_x_pol$n_fa) * 100, 1), "\n")
cat("% polizas donde ns == numero de filas:",
    round(mean(sin_x_pol$ns == sin_x_pol$n_filas) * 100, 1), "\n")

# Consistencia de contrato de poliza
const_vars <- c("ns","pot","ant","edad","bm","marca","comb","area","dens","ciudad")
inconsist_pol <- map_dfr(const_vars, function(v) {
  tibble(variable = v,
         polizas_con_mas_de_un_valor =
           sum(tapply(d[[v]], d$id, function(x) n_distinct(x) > 1)))
})
print(inconsist_pol) 

# ---- Consistencia de la base ----

#  Fechas
cat("Pagos antes del accidente:", sum(d$lag < 0), "\n")
cat("Pagos el mismo dia:", sum(d$lag == 0), "\n")
cat("Rango accidentes:", format(range(d$fa)), "\n")
cat("Rango pagos:", format(range(d$fp)), "\n")
cat("Accidentes despues de la fecha de evaluacion:", sum(d$fa > fecha_eval), "\n")

#  Montos
cat("Pagos negativos:", sum(d$pago < 0), "\n")
cat("Pagos < 1 (centavos):", sum(d$pago >= 0 & d$pago < 1), "\n")
cat("Pagos > 50,000 (por pago):", sum(d$pago > 50000), "\n")

# El limite de 50,000 aplica por SINIESTRO, no por pago -> revisar acumulado
sin <- d %>% distinct() %>%
  group_by(id, fa) %>% summarise(total = sum(pago), n_pagos = n(), .groups = "drop")
cat("Siniestros con total > 50,000:", sum(sin$total > 50000), "\n")

# Negativos
neg <- d %>% filter(pago < 0) %>% dplyr::select(id, fa)
print(d %>% semi_join(neg, by = c("id","fa")) %>% arrange(id, fa, fp) %>%
        dplyr::select(id, fa, fp, pago, lag))

#Duplicados
cat("Duplicados exactos:", sum(duplicated(d)), "\n")
cat("Mismo (id, fa, pago):", sum(duplicated(d[, c("id","fa","pago")])), "\n")
cat("Mismo (id, fa, fp) con monto distinto:",
    sum(duplicated(d[, c("id","fa","fp")])), "\n")

#  Redondeo / valores repetidos en montos
d <- d %>% mutate(dos_dec = abs(pago - round(pago, 2)) < 1e-9)
cat("% de pagos con exactamente 2 decimales:", round(mean(d$dos_dec) * 100, 1), "\n")

# Variables de poliza: rangos y coherencia
summary(pol[, c("pot","ant","edad","bm","dens")])
cat("Edad > 90:", sum(pol$edad > 90), "| Antigüedad == 0:", sum(pol$ant == 0), "\n")
cat("BM en el piso (50):", round(mean(pol$bm == 50) * 100, 1), "%\n")
cat("Densidad top-codificada (27000):", sum(pol$dens == 27000), "\n")

# =====================================================================
# C. FALTANTES: MCAR / LITTLE
# =====================================================================
cat("\n--- C. Faltantes ---\n")
cat("NA totales:", sum(is.na(d)), "\n")
# Con 0 NA, la prueba de Little NO aplica sobre los datos crudos.
# El faltante es "encubierto": valores presentes pero fabricados/imputados.
# Estrategia: marcar como NA la fecha de pago en la ventana sospechosa
# (lag == 540) y probar si ese faltante es MCAR respecto a las covariables.

d <- d %>% mutate(sospechoso = lag == 540)

d_na <- d %>% mutate(fp_na = if_else(sospechoso, as.Date(NA), fp),
                     lag_na = if_else(sospechoso, NA_real_, lag))

#  Little en el conjunto de covariables numericas + lag con NA
num_cov <- d_na %>% mutate(fa_num = as.numeric(fa)) %>%
  dplyr::select(lag_na, pago, fa_num, pot, ant, edad, bm, dens, ns)
print(mcar_test(num_cov))

# H0: faltantes MCAR. p pequeno => NO es MCAR (depende de otras variables).

# C2. El indicador de anomalia contra covariables (solo donde era posible)
# El lag 540 solo puede existir si fa + 540 <= fecha_eval  => fa <= eval - 540
elegibles <- d %>% filter(fa <= fecha_eval - 540)
cat("Filas elegibles (fa + 540 <= evaluacion):", nrow(elegibles),
    "| % sospechosas:", round(mean(elegibles$sospechoso) * 100, 1), "\n")

cat_vars <- c("marca","comb","area","ciudad")
for (v in cat_vars) {
  t <- table(elegibles[[v]], elegibles$sospechoso)
  cat(v, "- chi2 p =", round(suppressWarnings(chisq.test(t))$p.value, 3), "\n")
}
num_vars <- c("ns","pot","ant","edad","bm","dens")
for (v in num_vars) {
  p <- wilcox.test(elegibles[[v]] ~ elegibles$sospechoso)$p.value
  cat(v, "- Wilcoxon p =", round(p, 3), "\n")
}

# Regresion logistica: que explica ser sospechoso?
mod <- glm(sospechoso ~ pot + ant + edad + bm + log(dens) + ns +
             marca + comb + area,
           data = elegibles, family = binomial)
print(summary(mod))
# Si nada es significativo => la anomalia es independiente de las covariables
# de la poliza (MCAR condicional a la fecha del accidente).

# Dependencia con el TIEMPO (esto si deberia salir)
print(d %>% mutate(trim_fa = paste0(year(fa), "Q", quarter(fa))) %>%
        group_by(trim_fa) %>%
        summarise(n = n(), sospechosos = sum(sospechoso),
                  pct = round(mean(sospechoso) * 100, 1)))

# Diferencia en el MONTO entre sospechosos y no sospechosos
print(wilcox.test(pago ~ sospechoso, data = elegibles))
print(d %>% group_by(sospechoso) %>%
        summarise(n = n(), mediana = median(pago), p25 = quantile(pago, .25),
                  media = mean(pago), pct_menor_1 = mean(pago < 1) * 100,
                  pct_dos_dec = mean(dos_dec) * 100, suma = sum(pago)))


# Anomalia Lag = 540

# Es un solo dia exacto o una ventana?
print(d %>% filter(lag >= 500, lag <= 580) %>% count(lag) %>%
        arrange(desc(n)) %>% head(5))


# Aparece en todos los trimestres de accidente? de pago?
print(table(paste0(year(d$fa), "Q", quarter(d$fa)), d$sospechoso))
print(table(paste0(year(d$fp), "Q", quarter(d$fp)), d$sospechoso))

# . Dia de la semana (una fecha sintetica no respeta patrones semanales reales)
print(round(prop.table(table(wday(d$fp), d$sospechoso), 2), 3))

# Posicion dentro del siniestro: es siempre el ultimo pago? el primero?
d <- d %>% arrange(id, fa, fp) %>% group_by(id, fa) %>%
  mutate(orden_pago = row_number(), n_pagos = n()) %>% ungroup()
print(table(d$orden_pago[d$n_pagos > 1], d$sospechoso[d$n_pagos > 1]))

# Cuantos siniestros tienen mas de un pago sospechoso?
print(table(d %>% group_by(id, fa) %>%
              summarise(k = sum(sospechoso), .groups = "drop") %>% pull(k)))

# Montos: distribucion mixta (centavos + valores repetidos)
print(d %>% filter(sospechoso) %>% count(monto = round(pago, 2), sort = TRUE) %>%
        head(8))

ggplot(d, aes(x = log10(pmax(pago, 1e-3)), fill = sospechoso)) +
  geom_histogram(bins = 60, alpha = 0.7, position = "identity") +
  labs(title = "Pago (log10) segun lag == 540", x = "log10(pago)", y = "Frecuencia") +
  theme_minimal()

ggplot(d, aes(x = lag, fill = sospechoso)) +
  geom_histogram(binwidth = 10) +
  labs(title = "Lag por dia con la anomalia resaltada") + theme_minimal()

# Peso monetario de la anomalia
cat("% de filas:", round(mean(d$sospechoso) * 100, 1),
    "| % del monto total:", round(sum(d$pago[d$sospechoso]) / sum(d$pago) * 100, 1), "\n")


# Cuantos siniestros tienen exactamente UN pago con lag 540?
sin_540 <- d %>% group_by(id, fa) %>%
  summarise(k = sum(sospechoso), n_pagos = n(), .groups = "drop") %>%
  mutate(elegible = fa <= fecha_eval - 540)
print(table(elegible = sin_540$elegible, pagos_540 = sin_540$k))
# Si ~100% de los elegibles tiene exactamente 1 => no es ruido aleatorio,
# es un registro sistematico por siniestro.

# Comparacion a IGUAL madurez (300 dias): siniestros con y sin la anomalia
madurez <- 300
comp <- d %>% filter(!sospechoso, lag <= madurez) %>%
  group_by(id, fa) %>% summarise(np = n(), monto = sum(pago), .groups = "drop")
sin_todos <- d %>% distinct(id, fa) %>% filter(fa <= fecha_eval - madurez) %>%
  left_join(comp, by = c("id","fa")) %>%
  mutate(np = replace_na(np, 0), monto = replace_na(monto, 0),
         semestre = paste0(year(fa), "H", ifelse(month(fa) <= 6, 1, 2)))
print(sin_todos %>% group_by(semestre) %>%
        summarise(siniestros = n(), pagos_x_sin = mean(np),
                  monto_x_sin = mean(monto), pct_sin_pago = mean(np == 0)))
# Si los siniestros afectados tienen ~la mitad de pagos "limpios" que los
# posteriores, es consistente con que el registro de 540 dias sea un pago
# real cuya FECHA fue sobrescrita.



# ---- Fecha de evaluación ----

# Lag maximo posible por fecha de accidente = fecha_eval - fa
d <- d %>% mutate(lag_max_posible = as.numeric(fecha_eval - fa),
                  anio_fa = year(fa))
print(d %>% group_by(anio_fa) %>%
        summarise(n = n(), lag_med = median(lag), lag_max = max(lag),
                  max_posible = max(lag_max_posible)))

# Numero de pagos observados por trimestre de accidente vs trimestre de pago
tri <- d %>% mutate(trim_fa = paste0(year(fa), "Q", quarter(fa)),
                    trim_fp = paste0(year(fp), "Q", quarter(fp))) %>%
  count(trim_fa, trim_fp) %>%
  pivot_wider(names_from = trim_fp, values_from = n, values_fill = 0)
print(tri)   

print(d %>% mutate(trim_fp = paste0(year(fp), "Q", quarter(fp))) %>%
        group_by(trim_fp) %>%
        summarise(n = n(), n_sosp = sum(sospechoso), monto = sum(pago),
                  monto_sosp = sum(pago[sospechoso])))


