library(readxl)
library(dplyr)
library(tidyr) 

datos <- read_excel("C:/Users/Carlos Estrada/Desktop/CAS/Datos_tendencia.xlsx")

datos$frec <- datos$`Num de Siniestros` / datos$`Exposiciones Devengadas`
datos$sev <- datos$`Siniestros Total` / datos$`Num de Siniestros`
datos$prima_pura <- datos$`Siniestros Total` / datos$`Exposiciones Devengadas`

evaluar_tendencia <- function(df, n_puntos, variable) {
  df_n <- tail(df, n_puntos)
  
  y <- df_n[[variable]]
  t <- 0:(n_puntos - 1)
  
  modelo <- lm(log(y) ~ t)
  y_pred <- exp(fitted(modelo))
  
  r_trimestral <- as.numeric(coef(modelo)[2])
  tendencia_anual <- r_trimestral * 4
  
  mse <- mean((y - y_pred)^2)
  mape <- mean(abs((y - y_pred) / y)) * 100
  
  ss_res <- sum((y - y_pred)^2)
  ss_tot <- sum((y - mean(y))^2)
  r2 <- 1 - (ss_res / ss_tot)
  
  data.frame(
    Periodo_Num = n_puntos,
    Periodo = paste(n_puntos, "pt"),
    Variable = variable,
    Tendencia_Num = tendencia_anual,
    Tendencia_Anual = sprintf("%.2f%%", tendencia_anual * 100),
    R2 = round(r2, 4),
    MAPE_pct = round(mape, 2),
    MSE = round(mse, 6)
  )
}

periodos <- c(20, 12, 8, 6)
variables <- c("frec", "sev", "prima_pura")

resultados_lista <- list()
contador <- 1

for (var in variables) {
  for (n in periodos) {
    resultados_lista[[contador]] <- evaluar_tendencia(datos, n, var)
    contador <- contador + 1
  }
}

resultados_df <- do.call(rbind, resultados_lista)

tabla_comparativa <- resultados_df %>%
  select(Periodo_Num, Periodo, Variable, Tendencia_Num) %>%
  pivot_wider(names_from = Variable, values_from = Tendencia_Num) %>%
  arrange(desc(Periodo_Num)) %>% 
  mutate(
    PP_Estimada_Num = ((1 + frec) * (1 + sev)) - 1,
    Frecuencia = sprintf("%.2f%%", frec * 100),
    Severidad = sprintf("%.2f%%", sev * 100),
    Prima_Pura_Estimada = sprintf("%.2f%%", PP_Estimada_Num * 100),
    Prima_Pura_Directa = sprintf("%.2f%%", prima_pura * 100)
  ) %>%
  select(Periodo, Frecuencia, Severidad, Prima_Pura_Estimada, Prima_Pura_Directa)

# Frecuencia
print(resultados_df %>% filter(Variable == "frec") %>% select(Periodo, Tendencia_Anual, R2, MAPE_pct, MSE))

# Severidad
print(resultados_df %>% filter(Variable == "sev") %>% select(Periodo, Tendencia_Anual, R2, MAPE_pct, MSE))

# Prima Pura
print(resultados_df %>% filter(Variable == "prima_pura") %>% select(Periodo, Tendencia_Anual, R2, MAPE_pct, MSE))

# Tabla comparativa
print(as.data.frame(tabla_comparativa))

