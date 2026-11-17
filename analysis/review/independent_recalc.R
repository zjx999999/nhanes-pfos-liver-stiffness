suppressPackageStartupMessages({
  library(haven)
  library(survey)
})

# Independent minimal recalculation of phase-9 base and extended models.
# This intentionally does not source scripts/cross_cycle_analysis.R.
args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("^--file=", "", args[grepl("^--file=", args)][1])
phase_root <- normalizePath(file.path(dirname(script_arg), ".."), mustWork = TRUE)
project <- normalizePath(Sys.getenv("NHANES_DATA_ROOT", unset = file.path(dirname(phase_root), "phase6_nhanes_2026-11-14")), mustWork = TRUE)
read_cycle <- function(suffix, raw_dir, weight_var) {
  read <- function(stem) read_xpt(file.path(project, raw_dir, paste0(stem, "_", suffix, ".xpt")))
  frames <- list(
    read("DEMO")[, c("SEQN", "RIDAGEYR", "RIAGENDR", "RIDRETH3", "SDMVSTRA", "SDMVPSU")],
    read("PFAS")[, c("SEQN", weight_var, "LBXNFOS", "LBXMFOS")],
    read("LUX")[, c("SEQN", "LUAXSTAT", "LUXSMED")],
    read("BMX")[, c("SEQN", "BMXBMI")],
    read("DIQ")[, c("SEQN", "DIQ010")],
    read("ALQ")[, c("SEQN", "ALQ111", "ALQ121")]
  )
  d <- Reduce(function(x, y) merge(x, y, by = "SEQN", all.x = TRUE, sort = FALSE), frames)
  d$weight <- d[[weight_var]]
  d$eligible <- !is.na(d$RIDAGEYR) & d$RIDAGEYR >= 20 &
    !is.na(d$weight) & d$weight > 0 & !is.na(d$LUAXSTAT) & d$LUAXSTAT == 1
  d$PFOS_total <- d$LBXNFOS + d$LBXMFOS
  d$log2_PFOS <- ifelse(d$PFOS_total > 0, log2(d$PFOS_total), NA_real_)
  d$log_LSM <- ifelse(d$LUXSMED > 0, log(d$LUXSMED), NA_real_)
  d$sex <- factor(d$RIAGENDR, levels = c(1, 2), labels = c("Male", "Female"))
  d$race_group <- factor(ifelse(d$RIDRETH3 == 3, "NH White",
    ifelse(d$RIDRETH3 == 4, "NH Black",
      ifelse(d$RIDRETH3 %in% c(1, 2), "Hispanic",
        ifelse(d$RIDRETH3 %in% c(6, 7), "Other", NA_character_)))))
  d$diabetes <- factor(ifelse(d$DIQ010 == 1, "Diagnosed",
    ifelse(d$DIQ010 %in% c(2, 3), "No/borderline", NA_character_)),
    levels = c("No/borderline", "Diagnosed"))
  d$alcohol <- NA_character_
  d$alcohol[d$ALQ111 == 2] <- "lifetime_never"
  d$alcohol[d$ALQ111 == 1 & d$ALQ121 == 0] <- "former_past_year"
  d$alcohol[d$ALQ111 == 1 & d$ALQ121 %in% 1:5] <- "current_weekly_plus"
  d$alcohol[d$ALQ111 == 1 & d$ALQ121 %in% 6:10] <- "current_less_than_weekly"
  d$alcohol <- factor(d$alcohol, levels = c("lifetime_never", "former_past_year",
    "current_less_than_weekly", "current_weekly_plus"))
  d$complete_base <- complete.cases(d[, c("log2_PFOS", "log_LSM", "RIDAGEYR", "sex", "race_group")])
  d$complete_extended <- complete.cases(d[, c("log2_PFOS", "log_LSM", "RIDAGEYR", "sex",
    "race_group", "BMXBMI", "diabetes", "alcohol")])

  design_data <- d[!is.na(d$weight) & d$weight > 0 & !is.na(d$SDMVSTRA) & !is.na(d$SDMVPSU), ]
  des <- svydesign(ids = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~weight,
    nest = TRUE, data = design_data)
  models <- list(
    base_available = list(formula = log_LSM ~ log2_PFOS + RIDAGEYR + sex + race_group,
      subset = quote(eligible & complete_base)),
    extended_complete = list(formula = log_LSM ~ log2_PFOS + RIDAGEYR + sex + race_group +
      BMXBMI + diabetes + alcohol, subset = quote(eligible & complete_extended))
  )
  out <- lapply(names(models), function(name) {
    m <- models[[name]]
    dm <- subset(des, eval(m$subset))
    fit <- svyglm(m$formula, design = dm)
    b <- unname(coef(fit)["log2_PFOS"])
    s <- unname(SE(fit)["log2_PFOS"])
    d_design <- degf(dm)
    d_residual <- df.residual(fit)
    data.frame(period = ifelse(suffix == "J", "2017-2018", "2021-2023"),
      model = name, n = nrow(model.frame(fit)), design_df = d_design,
      residual_df = d_residual, beta = b, se = s,
      ci_low = b - qt(.975, d_design) * s, ci_high = b + qt(.975, d_design) * s,
      p = 2 * pt(abs(b / s), d_design, lower.tail = FALSE),
      ci_low_residual = b - qt(.975, d_residual) * s,
      ci_high_residual = b + qt(.975, d_residual) * s,
      p_residual = 2 * pt(abs(b / s), d_residual, lower.tail = FALSE))
  })
  do.call(rbind, out)
}

results <- rbind(
  read_cycle("J", "data/raw_2017_2018", "WTSB2YR"),
  read_cycle("L", "data/raw", "WTSPF2YR")
)
print(results, row.names = FALSE, digits = 8)

# Reproduce both candidate variance contrasts to expose the df convention.
e <- results[results$model == "extended_complete", ]
v <- e$se^2
delta <- diff(e$beta)
se_delta <- sqrt(sum(v))
df_resid <- (sum(v))^2 / sum(v^2 / e$residual_df)
df_design <- (sum(v))^2 / sum(v^2 / e$design_df)
contrast <- data.frame(delta_2021_minus_2017 = delta, se = se_delta,
  df_using_model_residual = df_resid,
  ci_low_residual_df = delta - qt(.975, df_resid) * se_delta,
  ci_high_residual_df = delta + qt(.975, df_resid) * se_delta,
  p_residual_df = 2 * pt(abs(delta / se_delta), df_resid, lower.tail = FALSE),
  df_using_design_df = df_design,
  ci_low_design_df = delta - qt(.975, df_design) * se_delta,
  ci_high_design_df = delta + qt(.975, df_design) * se_delta,
  p_design_df = 2 * pt(abs(delta / se_delta), df_design, lower.tail = FALSE))
print(contrast, row.names = FALSE, digits = 8)

expected_path <- file.path(phase_root, "outputs", "primary_model_comparison.csv")
if (file.exists(expected_path)) {
  prior <- read.csv(expected_path)
  prior <- prior[prior$model %in% c("base_all_available", "extended_same_complete_cases"), ]
  results$model[results$model == "base_available"] <- "base_all_available"
  results$model[results$model == "extended_complete"] <- "extended_same_complete_cases"
  print(merge(results, prior, by.x = c("period", "model"),
    by.y = c("period", "model"), suffixes = c("_independent", "_phase7")), row.names = FALSE)
}

# v1.0.1 packaging amendment: serialize existing calculated objects; no formula or estimate change.
write.csv(results, file.path(phase_root, "outputs", "independent_primary_recalc.csv"), row.names = FALSE)
write.csv(contrast, file.path(phase_root, "outputs", "independent_period_contrast.csv"), row.names = FALSE)
