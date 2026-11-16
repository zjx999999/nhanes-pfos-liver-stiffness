**First download and extract `nhanes-pfos-liver-stiffness-v1.0.0.zip`, then change into its extracted directory. All paths below refer to the extracted package.**

# Reproduction instructions

## Environment

Historical analysis: R 4.5.3, survey 4.5, haven 2.5.5. The saved sessionInfo records transitive packages and the original operating system. It is not a fully resolved renv lockfile; a fresh platform can use different binary builds. Install fixed top-level versions from CRAN/its archives in a project-local library, for example with an independently installed CRAN pak:

```r
pak::pkg_install(c("survey@4.5", "haven@2.5.5"))
```

Set R_LIBS_USER to that project-local library as needed; no global package configuration is required. Python figure requirements are pinned in scripts/requirements_plot.txt. Python input/hash/comparison tools require only the standard library. The historical R downloader additionally requires the shasum command; the Python downloader is the default portable entry point and validates both size and SHA-256.

## Public source inputs

The manifest contains 20 inputs (10 per period). The old 18-file manifest omitted SMQ_J.xpt and SMQ_L.xpt although the main code reads them. They are now listed with their existing byte counts and hashes. Smoking fields do not enter any frozen model. This is an input-completeness correction, not a change to the model or frozen results.

```sh
python3 scripts/fetch_data.py
python3 scripts/fetch_data.py --verify-only
```

NHANES_DATA_ROOT defaults to input_data/ in the repository. Its child paths are those in local_relative_path. Existing correct inputs are verified and not downloaded again. Incorrect existing files are not silently overwritten. New downloads use temporary files, byte-size and SHA-256 verification before being moved into place.

## Fixed R analysis and independent code recalculation

```sh
bash run_reproduction.sh
```

The runner exports an explicit data-root environment variable for all scripts, preventing historical default paths from being used. It runs the unchanged main script, then the unchanged independent recalculation script, and finally compares new outputs with the frozen aggregates. New results are written under analysis/outputs/ and analysis/figures/, never over data/ or the published figures/.

The two R implementations were AI-assisted and do not replace an independent human statistical review. The comparison checks numerical reproduction, not scientific assumptions, and does not alter values to make a test pass.

## Figures without model refitting

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r scripts/requirements_plot.txt
.venv/bin/python scripts/plot_figures.py
```

The figure script reads data/ and writes figures/, evidence/, and Figure_Provenance.json. It produces PNG, PDF, SVG and EPS. These are transformations of saved aggregates, not model fitting.

## Which saved outputs are derived presentation files?

The main analysis writes core statistical CSVs. data/sensitivity_with_probe.csv is an existing presentation assembly: all rows of sensitivity_models.csv plus the probe-adjustment rows of primary_model_comparison.csv, with schema-renamed residual-df fields. data/derived_descriptive_median_differences.json records descriptive median formulas. Their provenance is retained; the raw main output tables remain the authority. The independent recalculation checks the primary estimates, not every secondary model.

## Three distinct checks

1. Input and code execution: reproduce from official XPT with the recorded versions.
2. Numerical agreement: compare frozen aggregates with newly generated output using scripts/compare_outputs.py; report mismatches without overwriting frozen files.
3. Scientific assessment: a real statistician must judge survey domain design, df choice, complete-case selection, confounding/mediation, measurement and the independent-period contrast. Passing the first two layers does not establish the third.

The historical analysis specification contains local historical-file references and earlier wording about independent review. Those paths document project history, not required inputs in this repository; their existence is not asserted as public files. The repository's analysis_history.md clarifies which review was AI-assisted and that real author/statistical approval remains pending.
