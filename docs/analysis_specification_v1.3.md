# Frozen Analysis Specification

Version 1.3 | 2026-11-14 | NHANES PFAS–liver elastography, 2017–2018 and 2021–2023

## Status and disclosure

This specification is finalized after the investigators and analyst have inspected exploratory outcomes from the 2021–2023 cycle and the initial two-cycle estimates. It is not a prospective registration and must not be described as preregistered. The prior exploration and resulting decisions are preserved in `phase6_nhanes_2026-11-14/outputs/exploratory_models.csv`, `phase6_nhanes_2026-11-14/phase6_feasibility_report.md`, and `phase6_nhanes_2026-11-14/phase7_statistical_review.md`. The current primary hypothesis and model are frozen regardless of significance.

## Question and estimand

Among NHANES adults aged 20 years or older with a positive PFAS subsample weight and a complete-quality VCTE examination, does the survey-weighted cross-sectional association between serum total PFOS and liver stiffness have a similar direction and magnitude in 2021–2023 as in 2017–2018?

Primary exposure is total PFOS in ng/mL, defined as the sum of measured linear n-PFOS and branched Sm-PFOS. The exposure is log2 transformed. Primary outcome is natural-log median LSM, `log(LUXSMED)`. The estimand is the adjusted difference in mean log LSM per doubling of total serum PFOS, separately within each NHANES period. It is an associational estimand, not a causal effect.

## Analysis population and survey design

Include participants aged >=20 years with `WTSPF2YR > 0` (2021–2023) or `WTSB2YR > 0` (2017–2018), and `LUAXSTAT == 1`. Build each survey design from the cycle-specific PFAS eligible sample frame with nonmissing `SDMVSTRA` and `SDMVPSU`, before applying the adult/VCTE target domain. Use that cycle's PFAS subsample weight, masked strata, and PSU with nested PSUs. Do not concatenate the cycles or their weights. The primary t reference distribution uses domain design df, defined as represented PSUs minus represented strata. Model-residual df from default `svyglm` output is retained as a prespecified conservative sensitivity; neither rule is selected by its P value.

## Frozen models

Primary model (clinical conditional association):

`log(LSM) ~ log2(total PFOS) + age + sex + harmonized race/ethnicity + BMI + diagnosed diabetes + alcohol category`.

Alcohol categories are lifetime never; lifetime drinker but none in past 12 months; past-year drinking less than weekly; and past-year drinking at least weekly. Lifetime-never structural skips are assigned to lifetime never. Refused, don't know, inconsistent routing, and true missing values remain missing and are excluded from complete-case regression. Diabetes is self-reported physician diagnosis (`DIQ010==1`) versus no/borderline (`2/3`). Race harmonization is fixed across cycles before fitting.

Base model, reported as a second adjustment tier: `log(LSM) ~ log2(total PFOS) + age + sex + harmonized race/ethnicity`. It is estimated both on all available cases and on the exact complete-case sample used by the primary model. The latter isolates covariate adjustment from sample selection; the former shows the combined change from sample restriction and adjustment.

BMI and diabetes can be downstream of long-term PFAS exposure and/or share causes with liver health. The primary model therefore estimates a conditional association at fixed measured metabolic status, not a total causal effect. Alcohol, age, sex, and race/ethnicity are included for comparability with the clinical/environmental literature and plausible confounding control. The base model is not automatically interpreted as an unconfounded total effect.

## Secondary analyses

The fixed secondary panel is total PFOS, total PFOA (n-PFOA plus branched PFOA), PFHxS, and PFNA against continuous `log(LSM)` and continuous `LUXCAPM` (dB/m), using the same primary covariates. The PFOS–log(LSM) hypothesis remains the sole primary test. Apply Holm adjustment separately within each cycle and outcome to the nonprimary tests: three PFAS tests for log(LSM) and four PFAS tests for CAP. Report estimates and 95% CIs regardless of adjusted P values. Do not elevate any secondary result to primary status.

## Prespecified sensitivity analyses

1. Add final VCTE probe (`LUAPNME`, M versus XL) to the primary model.
2. Exclude LSM >40 kPa to match a documented earlier-study restriction.
3. Add eGFR (2021 CKD-EPI creatinine equation) because renal function can affect circulating PFAS concentrations; report extra complete-case loss and compare included/excluded distributions.
4. Apply a Samala-aligned viral sensitivity restriction: require HBsAg negative and observed HCV antibody/RNA fields, and exclude participants positive on both HCV antibody and RNA. NHANES HCV RNA code 3 denotes negative antibody screening and is treated as no active infection evidence; antibody positivity alone is not treated as current viremia.
5. Reproduce the earlier article's drinking restriction only after verifying its exact definition and unit conversion; do not infer it from an ambiguous questionnaire item.
6. Report a CAP model with PFOS and the prespecified secondary panel; no data-driven thresholds, categorization, splines, mixture models, interactions, or machine learning are added in this phase.

Missing covariates are not mean-imputed. The primary analysis uses complete cases. Report per-variable missingness and survey-weighted characteristics of primary-model included and excluded target-domain participants. One sensitivity assigns unclassified alcohol records (refused, don't know, contradictory routing, or true missing) to a single explicit category while requiring the other primary model variables to be complete. This retains a larger analytic domain but does not recover alcohol status or correct missingness bias; the pooled category is heterogeneous and is interpreted only as a coding sensitivity. Multiple imputation is not planned unless a separate, defensible complex-survey imputation specification is reviewed before outcomes are examined.

## Cross-period contrast

Estimate the frozen primary model separately in each cycle. Calculate the difference `beta_2021_2023 - beta_2017_2018` with variance equal to the sum of the independent design-based variances. The primary Welch–Satterthwaite approximation uses each period's domain design df; a parallel sensitivity uses each model's residual df. This is a difference test, not an equivalence test. A nonsignificant interaction/difference is not evidence of equivalence. No clinical equivalence margin has been established.

## Quality, extremes, and PFAS laboratory values

Use CDC-provided PFAS values and LLOD imputations (LLOD/sqrt(2)); comment code 1 means below LLOD and 0 means at/above LLOD. Total PFOS/PFOA detection is considered above LLOD if at least one summed component is above LLOD. Preserve plausible extreme observations in the primary analysis; LSM >40 is a sensitivity restriction. Check nonpositive concentrations, component sums, missingness, exam status, and consistency of LSM/CAP/IQR fields before model fitting. Do not transform CAP in the primary secondary analysis.

## Decision log

- 2026-11-14: exploratory 2021–2023 PFOS–log(LSM) estimates had been inspected (base model n=1,913, beta=-0.0176; extended model n=1,653, beta approximately 0.00004 in the later recoded analysis). These are not confirmatory.
- 2026-11-14: 2017–2018 and 2021–2023 separate-cycle results and a cross-cycle difference were inspected. The current model is fixed to the extended clinical adjustment set because it was the originally proposed clinical conditional association; the base tier is retained and reported in parallel. This is not a significance-driven choice.
- 2026-11-14: the prior analysis detected and corrected a survey logical-variable coefficient indexing error in weighted detection estimates; all phase-8 estimates will be generated with numeric below-LLOD indicators.
- No further changes to the primary exposure, outcome, adjustment set, or test will be made based on observed P values. Any unavoidable implementation correction will be logged with the reason and old/new results.

### Technical amendment 1.1 (2026-11-14; not outcome driven)

- Historical phase-7 review found that its cross-period contrast used design df=15 while default `svyglm` coefficient tests used residual df=4. Phase 9 now uses domain design df for primary coefficient and contrast inference and retains model residual df as a sensitivity. Primary period-specific point estimates are unchanged.
- NHANES `LUXSIQRM` stores IQR/median as a percentage (e.g. 24.0 means 24%), not a 0-1 ratio. The strict numerical quality sensitivity therefore uses `<30`, and the LUX audit records status/measure/IQR consistency.
- The HCV RNA field's value 3 is a negative antibody-screen result, not a positive RNA test or missing result; viral restriction logic was amended using the CDC codebook.

### Technical amendment 1.2 (2026-11-14; multiplicity family clarification)

- Clarified that the sole primary PFOS–log(LSM) test is excluded from secondary Holm families. Thus, the log(LSM) family contains the other three PFAS, while the CAP family contains all four. The code already implemented this separation; this text amendment aligns the frozen specification with the executed script and does not change estimates.

### Technical amendment 1.3 (2026-11-14; inference and missingness sensitivity)

- Following independent statistical review and official CDC/NCHS and `survey::svyglm` guidance, cycle-specific primary coefficient tests and confidence intervals now use domain design df=15; default model-residual-df results are shown as a conservative sensitivity. No coefficients, standard errors, exposure, outcome, or adjustment set changed.
- The cycle contrast is reported under both rules: design-df primary and model-residual-df sensitivity. Neither test is an equivalence test.
- Added one alcohol-unclassified-category sensitivity that retains participants with otherwise complete primary covariates. It is not imputation, an MAR correction, or evidence that complete-case selection is ignorable.
