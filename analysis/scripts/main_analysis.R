suppressPackageStartupMessages({
  library(haven)
  library(survey)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("^--file=", "", args[grepl("^--file=", args)][1])
phase_root <- normalizePath(file.path(dirname(script_arg), ".."), mustWork = TRUE)
project_root <- normalizePath(file.path(phase_root, ".."), mustWork = TRUE)
default_source_root <- file.path(phase_root, "input_data")
source_root <- Sys.getenv("NHANES_DATA_ROOT", unset = default_source_root)
out <- file.path(phase_root, "outputs")
figures <- file.path(phase_root, "figures")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
dir.create(figures, recursive = TRUE, showWarnings = FALSE)

read_xpt_file <- function(path) read_xpt(path)
survey_term <- function(fit, design, term) {
  estimate <- unname(coef(fit)[term])
  se <- unname(sqrt(vcov(fit)[term, term]))
  df_design <- degf(design)
  df_residual <- fit$df.residual
  make_inference <- function(df) {
    statistic <- estimate / se
    c(df = unname(df), ci_low = unname(estimate - qt(.975, df) * se),
      ci_high = unname(estimate + qt(.975, df) * se),
      p = unname(2 * pt(abs(statistic), df = df, lower.tail = FALSE)))
  }
  design_inf <- make_inference(df_design)
  residual_inf <- make_inference(df_residual)
  values <- c(estimate, se, df_design, df_residual,
    design_inf["ci_low"], design_inf["ci_high"], design_inf["p"],
    residual_inf["ci_low"], residual_inf["ci_high"], residual_inf["p"])
  setNames(as.numeric(values), c("beta", "se", "design_df", "residual_df",
    "ci_low", "ci_high", "p", "ci_low_residual", "ci_high_residual", "p_residual"))
}
merge_keep <- function(left, right, vars) {
  right <- right[, intersect(c("SEQN", vars), names(right)), drop = FALSE]
  stopifnot(!anyDuplicated(left$SEQN), !anyDuplicated(right$SEQN))
  merge(left, right, by = "SEQN", all.x = TRUE, sort = FALSE)
}

derive_alcohol <- function(d) {
  d$alcohol_status <- NA_character_
  d$alcohol_audit <- "true_missing"
  d$alcohol_audit[d$ALQ111 == 2] <- "lifetime_never_structural_skip"
  d$alcohol_status[d$ALQ111 == 2] <- "lifetime_never"
  d$alcohol_audit[d$ALQ111 == 1 & d$ALQ121 == 0] <- "past_year_abstinent"
  d$alcohol_status[d$ALQ111 == 1 & d$ALQ121 == 0] <- "former_past_year"
  d$alcohol_audit[d$ALQ111 == 1 & d$ALQ121 %in% 1:5] <- "current_weekly_or_more"
  d$alcohol_status[d$ALQ111 == 1 & d$ALQ121 %in% 1:5] <- "current_weekly_plus"
  d$alcohol_audit[d$ALQ111 == 1 & d$ALQ121 %in% 6:10] <- "current_less_than_weekly"
  d$alcohol_status[d$ALQ111 == 1 & d$ALQ121 %in% 6:10] <- "current_less_than_weekly"
  d$alcohol_audit[d$ALQ111 == 1 & d$ALQ121 == 77] <- "refused_frequency"
  d$alcohol_audit[d$ALQ111 == 7 | d$ALQ121 == 77] <- "refused"
  d$alcohol_audit[d$ALQ111 == 1 & d$ALQ121 == 99] <- "dont_know_frequency"
  d$alcohol_audit[d$ALQ111 == 9 | d$ALQ121 == 99] <- "dont_know"
  d$alcohol_audit[d$ALQ111 == 9 & !is.na(d$ALQ121) & d$ALQ121 %in% 0:10] <- "routing_inconsistent_lifetime_unknown"
  d$alcohol_status[d$alcohol_audit %in% c("refused", "dont_know", "routing_inconsistent_lifetime_unknown")] <- NA_character_
  d$alcohol_status <- factor(d$alcohol_status, levels = c("lifetime_never", "former_past_year", "current_less_than_weekly", "current_weekly_plus"))
  d$alcohol_audit <- factor(d$alcohol_audit)
  d
}

load_cycle <- function(period, suffix, raw_dir, weight_name) {
  read <- function(stem) read_xpt_file(file.path(raw_dir, paste0(stem, "_", suffix, ".xpt")))
  dem <- read("DEMO")
  pfas <- read("PFAS")
  lux <- read("LUX")
  d <- dem[, c("SEQN", "RIDAGEYR", "RIAGENDR", "RIDRETH3", "SDMVSTRA", "SDMVPSU")]
  d <- merge_keep(d, pfas, c(weight_name, "LBXNFOS", "LBXMFOS", "LBDNFOSL", "LBDMFOSL", "LBXNFOA", "LBXBFOA", "LBDNFOAL", "LBDBFOAL", "LBXPFHS", "LBDPFHSL", "LBXPFNA", "LBDPFNAL", "LBXPFDE", "LBDPFDEL"))
  d <- merge_keep(d, lux, c("LUAXSTAT", "LUAPNME", "LUXSMED", "LUXCAPM", "LUXSIQR", "LUXSIQRM", "LUXCPIQR", "LUANMVGP", "LUANMTGP", "LUATECH"))
  d <- merge_keep(d, read("BMX"), c("BMXBMI", "BMXWAIST"))
  bio <- read("BIOPRO")
  d <- merge_keep(d, bio, c("LBXSCR", "LBXSATSI", "LBXSASSI", "LBXSGTSI"))
  d <- merge_keep(d, read("DIQ"), c("DIQ010"))
  alq <- read("ALQ")
  d <- merge_keep(d, alq, c("ALQ111", "ALQ121", "ALQ130", "ALQ142", "ALQ151"))
  d <- merge_keep(d, read("SMQ"), c("SMQ020", "SMQ040"))
  d <- merge_keep(d, read("HEPBD"), c("LBDHBG"))
  d <- merge_keep(d, read("HEPC"), c("LBXHCR", "LBDHCI"))

  d$period <- period
  d$weight <- d[[weight_name]]
  d$adult <- !is.na(d$RIDAGEYR) & d$RIDAGEYR >= 20
  d$pfas_sample <- !is.na(d$weight) & d$weight > 0
  d$lux_complete <- !is.na(d$LUAXSTAT) & d$LUAXSTAT == 1
  # LUXSIQRM is stored as percent (e.g. 24.0 means 24%), not as a 0-1 proportion.
  d$lux_numeric_quality <- !is.na(d$LUANMVGP) & d$LUANMVGP >= 10 & !is.na(d$LUXSIQRM) & d$LUXSIQRM < 30
  d$eligible <- d$adult & d$pfas_sample & d$lux_complete
  d$PFOS_total <- d$LBXNFOS + d$LBXMFOS
  d$PFOA_total <- d$LBXNFOA + d$LBXBFOA
  d$log2_PFOS <- ifelse(d$PFOS_total > 0, log2(d$PFOS_total), NA_real_)
  d$log2_PFOA <- ifelse(d$PFOA_total > 0, log2(d$PFOA_total), NA_real_)
  d$log2_nPFOA <- ifelse(d$LBXNFOA > 0, log2(d$LBXNFOA), NA_real_)
  d$log2_PFHxS <- ifelse(d$LBXPFHS > 0, log2(d$LBXPFHS), NA_real_)
  d$log2_PFNA <- ifelse(d$LBXPFNA > 0, log2(d$LBXPFNA), NA_real_)
  d$log_LSM <- ifelse(d$LUXSMED > 0, log(d$LUXSMED), NA_real_)
  d$race_group <- ifelse(d$RIDRETH3 == 3, "NH White", ifelse(d$RIDRETH3 == 4, "NH Black", ifelse(d$RIDRETH3 %in% c(1, 2), "Hispanic", ifelse(d$RIDRETH3 %in% c(6, 7), "Other", NA_character_))))
  d$sex <- factor(d$RIAGENDR, levels = c(1, 2), labels = c("Male", "Female"))
  d$probe <- factor(d$LUAPNME, levels = c("M", "XL"))
  d$race_group <- factor(d$race_group)
  d$diabetes <- ifelse(d$DIQ010 == 1, "Diagnosed", ifelse(d$DIQ010 %in% c(2, 3), "No/borderline", NA_character_))
  d$diabetes <- factor(d$diabetes, levels = c("No/borderline", "Diagnosed"))
  d <- derive_alcohol(d)
  d$egfr <- 142 * pmin(d$LBXSCR / ifelse(d$RIAGENDR == 2, 0.7, 0.9), 1) ^ ifelse(d$RIAGENDR == 2, -0.241, -0.302) * pmax(d$LBXSCR / ifelse(d$RIAGENDR == 2, 0.7, 0.9), 1) ^ -1.2 * 0.9938 ^ d$RIDAGEYR * ifelse(d$RIAGENDR == 2, 1.012, 1)
  d$HBV_positive <- d$LBDHBG == 1
  d$HCV_antibody_confirmed <- d$LBDHCI == 1
  d$HCV_RNA_positive <- d$LBXHCR == 1
  d$active_viral_positive <- d$HBV_positive | (d$HCV_antibody_confirmed & d$HCV_RNA_positive)
  d$LSM_gt40 <- !is.na(d$LUXSMED) & d$LUXSMED > 40
  d$lod_pfna <- d$LBDPFNAL == 1
  d$lod_pfhxs <- d$LBDPFHSL == 1
  d$lod_pfda <- d$LBDPFDEL == 1
  d$lod_total_pfos <- d$LBDNFOSL == 1 & d$LBDMFOSL == 1
  d$lod_total_pfoa <- d$LBDNFOAL == 1 & d$LBDBFOAL == 1
  d$complete_main <- complete.cases(d[, c("log2_PFOS", "log_LSM", "RIDAGEYR", "sex", "race_group", "BMXBMI", "diabetes", "alcohol_status")])
  d$main_complete <- d$eligible & d$complete_main
  d
}

cycles <- list(
  `2017-2018` = load_cycle("2017-2018", "J", file.path(source_root, "data", "raw_2017_2018"), "WTSB2YR"),
  `2021-2023` = load_cycle("2021-2023", "L", file.path(source_root, "data", "raw"), "WTSPF2YR")
)

sample_flow <- do.call(rbind, lapply(names(cycles), function(period) {
  d <- cycles[[period]]
  data.frame(period = period,
    stage = c("DEMO rows", "Age >=20", "PFAS positive-weight adults", "Complete LUX among adults", "Eligible adult PFAS/LUX intersection", "Eligible with LSM <=40", "Eligible complete main-model covariates"),
    n = c(nrow(d), sum(d$adult), sum(d$adult & d$pfas_sample), sum(d$adult & d$lux_complete), sum(d$eligible), sum(d$eligible & !d$LSM_gt40), sum(d$eligible & d$complete_main)))
}))
write.csv(sample_flow, file.path(out, "sample_flow.csv"), row.names = FALSE)

missingness <- do.call(rbind, lapply(names(cycles), function(period) {
  d <- cycles[[period]][cycles[[period]]$eligible, ]
  vars <- c("log2_PFOS", "log_LSM", "LUXCAPM", "RIDAGEYR", "sex", "race_group", "BMXBMI", "diabetes", "alcohol_status", "egfr", "probe", "LBXHCR", "LBDHCI", "LBDHBG")
  data.frame(period = period, variable = vars, n_domain = nrow(d), n_missing = vapply(vars, function(v) sum(is.na(d[[v]])), integer(1)),
    pct_missing = 100 * vapply(vars, function(v) mean(is.na(d[[v]])), numeric(1)))
}))
write.csv(missingness, file.path(out, "missingness.csv"), row.names = FALSE)

lux_quality_audit <- do.call(rbind, lapply(names(cycles), function(period) {
  x <- cycles[[period]][cycles[[period]]$eligible, ]
  data.frame(period = period, n = nrow(x), n_measures_below10 = sum(x$LUANMVGP < 10, na.rm = TRUE),
    n_iqr_ratio_ge30 = sum(x$LUXSIQRM >= 30, na.rm = TRUE),
    n_complete_status_outside_numeric_criteria = sum(!x$lux_numeric_quality, na.rm = TRUE),
    n_lsm_missing = sum(is.na(x$LUXSMED)), n_cap_missing = sum(is.na(x$LUXCAPM)),
    n_lsm_gt40 = sum(x$LSM_gt40, na.rm = TRUE), max_lsm = max(x$LUXSMED, na.rm = TRUE),
    max_cap = max(x$LUXCAPM, na.rm = TRUE), max_cap_iqr = max(x$LUXCPIQR, na.rm = TRUE))
}))
write.csv(lux_quality_audit, file.path(out, "lux_quality_extreme_audit.csv"), row.names = FALSE)

alcohol_audit <- do.call(rbind, lapply(names(cycles), function(period) {
  d <- cycles[[period]]
  x <- d[d$eligible, ]
  tab <- as.data.frame(table(x$alcohol_audit, useNA = "ifany"), stringsAsFactors = FALSE)
  names(tab) <- c("audit_category", "n")
  tab$period <- period
  tab
}))
write.csv(alcohol_audit, file.path(out, "alcohol_routing_audit.csv"), row.names = FALSE)

fits <- list()
period_estimates <- list()
selection_compare <- list()
exposure_summaries <- list()
secondary_models <- list()
table1_all <- list()
sensitivity_models <- list()
for (period in names(cycles)) {
  d <- cycles[[period]]
  pfas_frame <- d[d$pfas_sample & !is.na(d$SDMVSTRA) & !is.na(d$SDMVPSU), ]
  pfas_frame$model0_complete <- complete.cases(pfas_frame[, c("log2_PFOS", "log_LSM", "RIDAGEYR", "sex", "race_group")])
  pfas_frame$alcohol_missing_category <- as.character(pfas_frame$alcohol_status)
  pfas_frame$alcohol_missing_category[is.na(pfas_frame$alcohol_missing_category)] <- "Unknown/refused/routing/missing"
  pfas_frame$alcohol_missing_category <- factor(pfas_frame$alcohol_missing_category)
  for (flag in c("lod_total_pfos", "lod_total_pfoa", "lod_pfhxs", "lod_pfna")) {
    pfas_frame[[paste0(flag, "_num")]] <- as.numeric(pfas_frame[[flag]])
  }
  des <- svydesign(ids = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~weight, nest = TRUE, data = pfas_frame)

  model0_vars <- c("log2_PFOS", "log_LSM", "RIDAGEYR", "sex", "race_group")
  model1_vars <- c(model0_vars, "BMXBMI", "diabetes", "alcohol_status")
  model_probe_vars <- c(model1_vars, "probe")
  extended_complete <- d$eligible & d$complete_main
  model_rows <- list()
  for (spec in list(
    list(name = "base_all_available", vars = model0_vars, domain = d$eligible),
    list(name = "base_same_complete_cases", vars = model0_vars, domain = extended_complete),
    list(name = "extended_same_complete_cases", vars = model1_vars, domain = extended_complete),
    list(name = "extended_plus_probe_same_complete_cases", vars = model_probe_vars, domain = extended_complete)
  )) {
    used <- d$eligible & spec$domain & complete.cases(d[, spec$vars, drop = FALSE])
    dm <- switch(spec$name,
      base_all_available = subset(des, eligible & model0_complete),
      base_same_complete_cases = subset(des, main_complete),
      extended_same_complete_cases = subset(des, main_complete),
      extended_plus_probe_same_complete_cases = subset(des, main_complete & !is.na(probe)))
    form <- as.formula(paste("log_LSM ~", paste(setdiff(spec$vars, "log_LSM"), collapse = " + ")))
    fit <- svyglm(form, design = dm)
    coef_name <- "log2_PFOS"
    inf <- survey_term(fit, dm, coef_name)
    model_rows[[spec$name]] <- data.frame(period = period, model = spec$name, n = sum(used),
      beta = inf["beta"], se = inf["se"], design_df = inf["design_df"], residual_df = inf["residual_df"],
      ci_low = inf["ci_low"], ci_high = inf["ci_high"], p = inf["p"],
      ci_low_residual = inf["ci_low_residual"], ci_high_residual = inf["ci_high_residual"], p_residual = inf["p_residual"])
    fits[[paste(period, spec$name, sep = "_")]] <- fit
  }
  period_estimates[[period]] <- do.call(rbind, model_rows)

  unknown_design <- des
  unknown_domain <- d$eligible & complete.cases(d[, c("log2_PFOS", "log_LSM", "RIDAGEYR", "sex", "race_group", "BMXBMI", "diabetes")])
  unknown_fit_design <- subset(unknown_design, eligible & complete.cases(log2_PFOS, log_LSM, RIDAGEYR, sex, race_group, BMXBMI, diabetes))
  unknown_fit <- svyglm(log_LSM ~ log2_PFOS + RIDAGEYR + sex + race_group + BMXBMI + diabetes + alcohol_missing_category,
                        design = unknown_fit_design)
  unknown_inf <- survey_term(unknown_fit, unknown_fit_design, "log2_PFOS")
  sensitivity_models[[paste(period, "primary_unknown_alcohol_category", sep = "_")]] <- data.frame(
    period = period, sensitivity = "primary_unknown_alcohol_category", n = sum(unknown_domain),
    design_df = unknown_inf["design_df"], model_residual_df = unknown_inf["residual_df"],
    beta = unknown_inf["beta"], se = unknown_inf["se"], ci_low = unknown_inf["ci_low"],
    ci_high = unknown_inf["ci_high"], p = unknown_inf["p"],
    ci_low_residual = unknown_inf["ci_low_residual"], ci_high_residual = unknown_inf["ci_high_residual"],
    p_residual = unknown_inf["p_residual"])

  domain_select <- subset(des, eligible)
  chars <- c("RIDAGEYR", "BMXBMI", "PFOS_total", "LUXSMED", "LUXCAPM", "egfr")
  for (v in chars) {
    xx <- subset(domain_select, !is.na(get(v)))
    by <- svyby(as.formula(paste0("~", v)), ~main_complete, xx, svymean, na.rm = TRUE, vartype = c("se"), drop.empty.groups = TRUE)
    by_df <- as.data.frame(by)
    estimate_col <- setdiff(names(by_df), c("main_complete", grep("^se$|^se[._]", names(by_df), value = TRUE)))[1]
    se_col <- grep("^se$|^se[._]", names(by_df), value = TRUE)[1]
    selection_compare[[paste(period, v, sep = "_")]] <- data.frame(period = period, variable = v,
      included_complete_case = by_df$main_complete, mean = by_df[[estimate_col]], se = by_df[[se_col]])
  }

  table1_des <- subset(des, main_complete)
  table1_rows <- list()
  for (v in c("RIDAGEYR", "BMXBMI", "PFOS_total", "PFOA_total", "LBXPFHS", "LBXPFNA", "LUXSMED", "LUXCAPM", "egfr")) {
    dm <- subset(table1_des, !is.na(get(v)))
    mn <- svymean(as.formula(paste0("~", v)), dm, na.rm = TRUE)
    qq <- svyquantile(as.formula(paste0("~", v)), dm, quantiles = c(.25, .5, .75), ci = FALSE, na.rm = TRUE)
    qv <- as.numeric(coef(qq))
    table1_rows[[v]] <- data.frame(period = period, variable = v, category = "", n = nrow(dm$variables),
      weighted_mean = as.numeric(coef(mn)[1]), se = as.numeric(SE(mn)[1]), q25 = qv[1], median = qv[2], q75 = qv[3])
  }
  for (v in c("sex", "race_group", "diabetes", "alcohol_status", "probe")) {
    sm <- svymean(as.formula(paste0("~", v)), table1_des, na.rm = TRUE)
    for (j in seq_along(coef(sm))) {
      nm <- names(coef(sm))[j]
      table1_rows[[paste(v, nm, sep = "_")]] <- data.frame(period = period, variable = v,
        category = sub(paste0("^", v), "", nm), n = nrow(table1_des$variables), weighted_mean = as.numeric(coef(sm)[j]),
        se = as.numeric(SE(sm)[j]), q25 = NA_real_, median = NA_real_, q75 = NA_real_)
    }
  }
  table1_all[[period]] <- do.call(rbind, table1_rows)

  # Detection rates and exposure distribution use the cycle-specific PFAS subsample weight.
  evars <- c("PFOS_total", "PFOA_total", "LBXPFHS", "LBXPFNA")
  for (v in evars) {
    x <- d$eligible & !is.na(d[[v]])
    dx <- subset(des, eligible & !is.na(get(v)))
    quant <- svyquantile(as.formula(paste0("~", v)), dx, quantiles = c(.25, .5, .75), ci = FALSE, na.rm = TRUE)
    below_var <- if (v == "PFOS_total") "lod_total_pfos_num" else if (v == "PFOA_total") "lod_total_pfoa_num" else if (v == "LBXPFHS") "lod_pfhxs_num" else "lod_pfna_num"
    detection_rate <- svymean(as.formula(paste0("~", below_var)), subset(des, eligible & !is.na(get(v))), na.rm = TRUE)
    q <- as.numeric(coef(quant))
    exposure_summaries[[paste(period, v, sep = "_")]] <- data.frame(period = period, exposure = v, n = sum(x), weighted_detection = 1 - as.numeric(coef(detection_rate)[1]), q25 = q[1], median = q[2], q75 = q[3])
  }

  # Prespecified secondary panel: PFAS associations with LSM and CAP using the same covariate set.
  exp_vars <- c(PFOS_total = "log2_PFOS", PFOA_total = "log2_PFOA", PFHxS = "log2_PFHxS", PFNA = "log2_PFNA")
  for (outcome in c("log_LSM", "LUXCAPM")) {
    for (exposure in names(exp_vars)) {
      rhs <- c(exp_vars[[exposure]], "RIDAGEYR", "sex", "race_group", "BMXBMI", "diabetes", "alcohol_status")
      vars <- c(outcome, rhs)
      take <- d$eligible & complete.cases(d[, vars, drop = FALSE])
      subdesign <- subset(des, eligible & complete.cases(get(outcome), get(exp_vars[[exposure]]), RIDAGEYR, sex, race_group, BMXBMI, diabetes, alcohol_status))
      fit <- svyglm(as.formula(paste(outcome, "~", paste(rhs, collapse = " + "))), design = subdesign)
      term <- exp_vars[[exposure]]
      inf <- survey_term(fit, subdesign, term)
      secondary_models[[paste(period, outcome, exposure, sep = "_")]] <- data.frame(period = period, outcome = outcome, exposure = exposure,
        n = sum(take), beta = inf["beta"], se = inf["se"], design_df = inf["design_df"], residual_df = inf["residual_df"],
        ci_low = inf["ci_low"], ci_high = inf["ci_high"], p = inf["p"],
        ci_low_residual = inf["ci_low_residual"], ci_high_residual = inf["ci_high_residual"], p_residual = inf["p_residual"])
    }
  }

  sens_specs <- list(
    list(name = "primary_plus_eGFR", extra = "egfr", domain = "main_complete & !is.na(egfr)"),
    list(name = "primary_LSM_le40", extra = character(), domain = "main_complete & LUXSMED <= 40"),
    list(name = "primary_strict_numeric_LUX_quality", extra = character(), domain = "main_complete & lux_numeric_quality"),
    list(name = "primary_HBV_HCV_tests_negative", extra = character(), domain = "main_complete & HBsAg negative and no HCV RNA-positive seroconfirmed case"),
    list(name = "linear_nPFOA_primary_covariates", extra = "log2_nPFOA", domain = "main_complete")
  )
  for (spec in sens_specs) {
    message("Sensitivity: ", period, " / ", spec$name)
    rhs <- c(if (spec$name == "linear_nPFOA_primary_covariates") "log2_nPFOA" else "log2_PFOS",
      "RIDAGEYR", "sex", "race_group", "BMXBMI", "diabetes", "alcohol_status", spec$extra)
    rhs <- unique(rhs)
    subdesign <- switch(spec$name,
      primary_plus_eGFR = subset(des, main_complete & !is.na(egfr)),
      primary_LSM_le40 = subset(des, main_complete & LUXSMED <= 40),
      primary_strict_numeric_LUX_quality = subset(des, main_complete & lux_numeric_quality),
      primary_HBV_HCV_tests_negative = subset(des, main_complete & LBDHBG == 2 & !is.na(LBDHCI) & LBXHCR %in% 1:3 & !(LBDHCI == 1 & LBXHCR == 1)),
      linear_nPFOA_primary_covariates = subset(des, main_complete & !is.na(LBXNFOA) & LBXNFOA > 0))
    message(" rows=", nrow(subdesign$variables), "; factor levels: ", paste(vapply(subdesign$variables[c("sex", "race_group", "diabetes", "alcohol_status")], function(z) length(unique(z[!is.na(z)])), integer(1)), collapse = ","))
    fit <- svyglm(as.formula(paste("log_LSM ~", paste(rhs, collapse = " + "))), design = subdesign)
    term <- rhs[1]
    inf <- survey_term(fit, subdesign, term)
    sensitivity_models[[paste(period, spec$name, sep = "_")]] <- data.frame(period = period, sensitivity = spec$name,
      n = nrow(subdesign$variables), design_df = inf["design_df"], model_residual_df = inf["residual_df"],
      beta = inf["beta"], se = inf["se"], ci_low = inf["ci_low"], ci_high = inf["ci_high"], p = inf["p"],
      ci_low_residual = inf["ci_low_residual"], ci_high_residual = inf["ci_high_residual"], p_residual = inf["p_residual"])
  }
}

est <- do.call(rbind, period_estimates)
write.csv(est, file.path(out, "primary_model_comparison.csv"), row.names = FALSE)
write.csv(do.call(rbind, selection_compare), file.path(out, "complete_case_selection.csv"), row.names = FALSE)
write.csv(do.call(rbind, exposure_summaries), file.path(out, "exposure_distribution.csv"), row.names = FALSE)
secondary <- do.call(rbind, secondary_models)
secondary$p_holm_within_period_outcome <- NA_real_
for (period in unique(secondary$period)) for (outcome in unique(secondary$outcome)) {
  idx <- secondary$period == period & secondary$outcome == outcome
  if (outcome == "log_LSM") idx <- idx & secondary$exposure != "PFOS_total"
  secondary$p_holm_within_period_outcome[idx] <- p.adjust(secondary$p[idx], method = "holm")
}
write.csv(secondary, file.path(out, "secondary_models.csv"), row.names = FALSE)
write.csv(do.call(rbind, table1_all), file.path(out, "table1.csv"), row.names = FALSE)
write.csv(do.call(rbind, sensitivity_models), file.path(out, "sensitivity_models.csv"), row.names = FALSE)
write.csv(est[est$model %in% c("base_all_available", "base_same_complete_cases", "extended_same_complete_cases"), ], file.path(out, "table2.csv"), row.names = FALSE)
write.csv(secondary, file.path(out, "table3.csv"), row.names = FALSE)

# Samala-aligned, unweighted 2017-2018 comparison; exact alcohol and exposure cutpoint replication is unavailable.
eng_d <- cycles[["2017-2018"]]
eng_d$log2_LBXNFOS <- ifelse(eng_d$LBXNFOS > 0, log2(eng_d$LBXNFOS), NA_real_)
eng_d$log2_LBXMFOS <- ifelse(eng_d$LBXMFOS > 0, log2(eng_d$LBXMFOS), NA_real_)
eng_d$eng_eligible <- !is.na(eng_d$RIDAGEYR) & eng_d$RIDAGEYR >= 18 & eng_d$pfas_sample & eng_d$lux_complete &
  !is.na(eng_d$LUXSMED) & eng_d$LUXSMED <= 40 & eng_d$LUANMVGP >= 10 & eng_d$LUXSIQRM < 30 &
  eng_d$LBDHBG == 2 & !is.na(eng_d$LBDHCI) & !is.na(eng_d$LBXHCR) & !(eng_d$LBDHCI == 1 & eng_d$LBXHCR == 1)
eng_models <- list()
for (exposure in c(LBXNFOS = "log2_LBXNFOS", LBXMFOS = "log2_LBXMFOS", PFOS_total = "log2_PFOS")) {
  vv <- c(unname(exposure), "log_LSM", "RIDAGEYR", "sex", "race_group")
  dd <- eng_d[eng_d$eng_eligible & complete.cases(eng_d[, vv, drop = FALSE]), ]
  fit <- lm(as.formula(paste("log_LSM ~", unname(exposure), "+ RIDAGEYR + sex + race_group")), data = dd)
  term <- unname(exposure)
  ci <- confint(fit)[term, ]
  co <- summary(fit)$coefficients[term, ]
  eng_models[[exposure]] <- data.frame(exposure = exposure, n = nrow(dd), beta = co["Estimate"], se = co["Std. Error"], ci_low = ci[1], ci_high = ci[2], p = co["Pr(>|t|)"],
    note = "Unweighted age/sex/race adjusted approximation; not exact Eng replication")
}
write.csv(do.call(rbind, eng_models), file.path(out, "samala_aligned_2017_unweighted.csv"), row.names = FALSE)
eng_flow <- data.frame(stage = c("Age >=18", "PFAS weight >0", "LUX status complete", "LSM <=40 and numeric stiffness quality", "HBsAg negative and HCV tests observed; not both Ab/RNA positive", "PFOS available"),
  n = c(sum(eng_d$RIDAGEYR >= 18, na.rm = TRUE), sum(eng_d$RIDAGEYR >= 18 & eng_d$pfas_sample, na.rm = TRUE),
    sum(eng_d$RIDAGEYR >= 18 & eng_d$pfas_sample & eng_d$lux_complete, na.rm = TRUE), sum(eng_d$eng_eligible, na.rm = TRUE),
    sum(eng_d$eng_eligible, na.rm = TRUE), sum(eng_d$eng_eligible & !is.na(eng_d$PFOS_total), na.rm = TRUE)))
write.csv(eng_flow, file.path(out, "samala_aligned_flow.csv"), row.names = FALSE)

# Publication figures are drawn directly from the saved analysis tables.
png(file.path(figures, "figure1_sample_flow.png"), width = 1800, height = 1100, res = 180)
par(mar = c(1, 1, 2, 1)); plot.new(); plot.window(xlim = c(0, 1), ylim = c(0, 1))
text(.5, .96, "NHANES cycle-specific analysis populations", cex = 1.2, font = 2)
for (i in seq_along(names(cycles))) {
  period <- names(cycles)[i]; x <- if (i == 1) .25 else .75
  f <- sample_flow[sample_flow$period == period, ]
  box <- function(cx, cy, label, n, fill="#edf1f4", w=.27) {
    rect(cx-w/2, cy-.038, cx+w/2, cy+.038, col=fill, border="#607d78", lwd=1)
    text(cx, cy, paste0(label, "\nN=", n), cex=.65)
  }
  n <- setNames(f$n, f$stage)
  box(x, .84, "DEMO participants", n["DEMO rows"], w=.30)
  box(x, .72, "Age >=20 years", n["Age >=20"], w=.30)
  box(x-.12, .57, "PFAS positive weight", n["PFAS positive-weight adults"], w=.22)
  box(x+.12, .57, "LUX complete", n["Complete LUX among adults"], w=.22)
  box(x, .42, "Adult PFAS + LUX domain", n["Eligible adult PFAS/LUX intersection"], fill="#e4edf4", w=.34)
  box(x-.12, .27, "LSM <=40 sensitivity", n["Eligible with LSM <=40"], w=.22)
  box(x+.12, .27, "Primary complete cases", n["Eligible complete main-model covariates"], fill="#dcefe7", w=.22)
  arrows(x, .80, x, .765, length=.07, col="#566")
  arrows(x-.02, .68, x-.10, .62, length=.07, col="#566"); arrows(x+.02, .68, x+.10, .62, length=.07, col="#566")
  arrows(x-.10, .53, x-.03, .46, length=.07, col="#566"); arrows(x+.10, .53, x+.03, .46, length=.07, col="#566")
  arrows(x-.03, .38, x-.10, .31, length=.07, col="#566"); arrows(x+.03, .38, x+.10, .31, length=.07, col="#566")
  text(x, .90, period, cex = 1, font = 2)
}
text(.5, .13, "LSM >40 is excluded only in a sensitivity analysis; primary models retain these observations.", cex=.72)
dev.off()

forest <- est[est$model %in% c("base_all_available", "base_same_complete_cases", "extended_same_complete_cases"), ]
forest$label <- paste(forest$period, c(base_all_available="Base, available cases", base_same_complete_cases="Base, same complete cases", extended_same_complete_cases="Extended, complete cases")[forest$model], sep = " | ")
png(file.path(figures, "figure2_primary_forest.png"), width = 1800, height = 1200, res = 180)
par(mar = c(5, 14, 3, 2)); ord <- rev(seq_len(nrow(forest)))
plot(forest$beta[ord], seq_along(ord), xlim = range(c(forest$ci_low, forest$ci_high, 0)), yaxt = "n", ylab = "", xlab = "Difference in mean log(LSM) per doubling of total PFOS (95% CI)", pch = 19, cex = 1.1)
segments(forest$ci_low[ord], seq_along(ord), forest$ci_high[ord], seq_along(ord), lwd = 2)
abline(v = 0, lty = 2, col = "grey40"); axis(2, at = seq_along(ord), labels = forest$label[ord], las = 1, cex.axis = .78)
title("Primary PFOS–LSM association by NHANES period and adjustment tier")
dev.off()

exp_plot <- read.csv(file.path(out, "exposure_distribution.csv"))
png(file.path(figures, "figure3_pfas_distribution.png"), width = 1800, height = 1100, res = 180)
par(mar = c(5, 6, 3, 2)); exps <- unique(exp_plot$exposure); cols <- c("#326b5b", "#bb5a42")
exp_labels <- c(PFOS_total="Total PFOS", PFOA_total="Total PFOA", LBXPFHS="PFHxS", LBXPFNA="PFNA")
plot(NA, xlim = c(.5, length(exps)+.5), ylim = range(exp_plot$q25, exp_plot$q75, na.rm = TRUE), xaxt = "n", xlab = "PFAS analyte", ylab = "Serum concentration (ng/mL)", log = "y")
axis(1, at = seq_along(exps), labels = exp_labels[exps]); title("Survey-weighted PFAS concentration distributions by period")
for (i in seq_along(exps)) for (j in 1:2) {
  z <- exp_plot[exp_plot$exposure == exps[i] & exp_plot$period == c("2017-2018", "2021-2023")[j], ]
  xx <- i + if (j == 1) -.12 else .12
  segments(xx, z$q25, xx, z$q75, col = cols[j], lwd = 3); points(xx, z$median, pch = 19, col = cols[j])
}
legend("topright", legend = c("2017–2018", "2021–2023"), col = cols, pch = 19, lwd = 2, bty = "n")
dev.off()

# Cross-period contrasts use independent estimates; design-df inference is primary and model-residual df is a sensitivity.
main <- est[est$model == "extended_same_complete_cases", ]
v1 <- main$se[main$period == "2017-2018"]^2
v2 <- main$se[main$period == "2021-2023"]^2
b1 <- main$beta[main$period == "2017-2018"]
b2 <- main$beta[main$period == "2021-2023"]
diff_beta <- b2 - b1
se_diff <- sqrt(v1 + v2)
df_design1 <- est$design_df[est$period == "2017-2018" & est$model == "extended_same_complete_cases"]
df_design2 <- est$design_df[est$period == "2021-2023" & est$model == "extended_same_complete_cases"]
df_resid1 <- est$residual_df[est$period == "2017-2018" & est$model == "extended_same_complete_cases"]
df_resid2 <- est$residual_df[est$period == "2021-2023" & est$model == "extended_same_complete_cases"]
contrast_row <- function(label, d1, d2) {
  df <- (v1 + v2)^2 / (v1^2 / d1 + v2^2 / d2)
  statistic <- diff_beta / se_diff
  data.frame(inference = label, beta_difference_2021_minus_2017 = diff_beta, se = se_diff, df = df,
    ci_low = diff_beta - qt(.975, df) * se_diff, ci_high = diff_beta + qt(.975, df) * se_diff,
    p_difference = 2 * pt(abs(statistic), df = df, lower.tail = FALSE),
    interpretation = "Difference test only; a non-significant result does not establish equivalence.")
}
cycle_contrast <- rbind(contrast_row("design_df_primary", df_design1, df_design2),
                        contrast_row("model_residual_df_sensitivity", df_resid1, df_resid2))
write.csv(cycle_contrast, file.path(out, "cycle_effect_difference.csv"), row.names = FALSE)
df_sensitivity <- rbind(
  data.frame(period = main$period, model = "extended_same_complete_cases", inference = "design_df_primary",
    beta = main$beta, se = main$se, df = main$design_df, ci_low = main$ci_low, ci_high = main$ci_high, p = main$p),
  data.frame(period = main$period, model = "extended_same_complete_cases", inference = "model_residual_df_sensitivity",
    beta = main$beta, se = main$se, df = main$residual_df, ci_low = main$ci_low_residual, ci_high = main$ci_high_residual, p = main$p_residual))
write.csv(df_sensitivity, file.path(out, "inference_df_sensitivity.csv"), row.names = FALSE)

writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))
cat("Analysis complete. Eligible n by period:", paste(sample_flow$period[sample_flow$stage == "Eligible adult PFAS/LUX intersection"], sample_flow$n[sample_flow$stage == "Eligible adult PFAS/LUX intersection"], sep = "=", collapse = "; "), "\n")
