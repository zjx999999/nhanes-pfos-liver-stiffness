# NHANES PFOS and liver stiffness reproducibility archive

Materials for **Cross-Period Comparison of Serum PFOS and Liver Stiffness Associations in NHANES 2017–2018 and 2021–2023**.

## Download the complete versioned code package

[Download the v1.0.0 reproducibility ZIP](nhanes-pfos-liver-stiffness-v1.0.0.zip) and its [SHA-256 checksum](nhanes-pfos-liver-stiffness-v1.0.0.zip.sha256). The archive preserves the original executable directory structure. Extract it before running any commands. The code, full input manifest, saved aggregates, model specification, environment record, figure source and per-file checksum manifest are **inside the ZIP**, not separate top-level GitHub folders.

```sh
unzip nhanes-pfos-liver-stiffness-v1.0.0.zip
cd nhanes-pfos-liver-stiffness-v1.0.0
python3 scripts/verify_payload.py
```

The package contains the unchanged main R analysis and separate primary-model recalculation code, official CDC download addresses and SHA-256 for all 20 XPT dependencies, 17 frozen statistical CSVs plus a descriptive formula record, and the source of six main figures and one supplementary roadmap. No participant-level data or full manuscript is uploaded.

The historical 18-file manifest omitted two SMQ files read by the original code; this release lists them without changing the code, covariates or frozen models. Repository assembly verified existing input hashes and code syntax but did not refit models.

See [reproduction instructions](REPRODUCIBILITY.md) and [availability statement](DATA_AND_CODE_AVAILABILITY.md). The full README, history disclosure and scientific interpretation are included in the archive. Analysis decisions followed exploratory inspection and are not prospective preregistration. The R recalculation is a separate AI-assisted implementation, not evidence of completed independent human statistical review. Real author/statistical/clinical approval remains necessary.

Original data: [CDC/NCHS NHANES](https://wwwn.cdc.gov/nchs/nhanes/). Earlier related work: [Samala et al. 2024](https://doi.org/10.1093/toxsci/kfae106). Cross-sectional associations are not causal effects; nonsignificance is not absence or equivalence.

The repository does not assert authorship or institutional affiliation from the uploader's GitHub account. No license, article DOI, publication acceptance, ethics determination or human-review approval has been invented. Final rights/licensing decisions remain with the real authors.
