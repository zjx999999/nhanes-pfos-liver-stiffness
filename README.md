# NHANES PFOS and liver stiffness reproducibility

Authors: Jiuxi Zhu, Yinlong Zuo, Yixiao Liu and Zhiyi Lin. Lanzhou University, Lanzhou, China. Correspondence: 320220908491@lzu.edu.cn.

This v1.0.1 technical source snapshot retains the original R analysis, independent recalculation and 17 frozen statistical CSVs. It adds a repository-contained IAOEH figure entry point. No new model or scientific result is introduced.

## Reproduce the frozen analysis

Use `run_reproduction.sh` with the 20-input manifest. It downloads official NHANES XPT inputs, runs the R analysis and separate implementation, assembles the saved sensitivity presentation, and compares all 17 CSVs. Read the versioned analysis specification, execution history, package/session information and `docs/RESEARCH_HISTORY_ERRATA.md` first. This editing task does not rerun R or claim a new end-to-end reproduction.

## Reproduce IAOEH presentation figures

Install the fixed versions in `scripts/requirements_plot.txt`, then run `python3 scripts/plot_iaoeh.py`. It reads saved aggregates from `data/`, writes Fig1–Fig3 and FigS1–FigS4 in PNG/PDF/SVG/EPS to `figures/iaoeh/`, and records geometry and plotted rows in `evidence/`. It fits no model. Arial is used where installed; a missing font may change layout and should be reported rather than silently treated as byte-identical reproduction.

## Authorship and history

Substantive AI assistance and the distinction between author-reported supervision/review and AI-agent execution are disclosed in `docs/AI_USE_AND_AUTHOR_REVIEW.md`. The latest author-confirmed scopes are data review by Jiuxi Zhu, manuscript review by Yinlong Zuo, reproducibility review by Yixiao Liu and reference review by Zhiyi Lin. The specification was finalized after exploratory viewing and is not prospective preregistration.

## Version and rights

The verified public archive remains https://github.com/zjx999999/nhanes-pfos-liver-stiffness/releases/tag/v1.0.0 . The public status and commit of v1.0.1 are established by its GitHub Release record. `LICENSE` applies to original project code; no participant-level XPT, credentials, private editorial audits or third-party full-text papers are distributed. See `docs/RELEASE_STATUS.md` and `docs/LICENSING_SCOPE.md`.
