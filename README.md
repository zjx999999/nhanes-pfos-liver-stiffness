# NHANES PFOS and liver stiffness reproducibility

Authors (in order): Jiuxi Zhu, Yinlong Zuo, Yixiao Liu and Zhiyi Lin. All authors: Lanzhou University, Lanzhou, Gansu, China. First and corresponding author: Jiuxi Zhu; 320220908491@lzu.edu.cn.

This v1.0.2 source snapshot retains the original R analysis, independent recalculation and 17 frozen statistical CSVs. The repository-contained IAOEH figure entry point is retained unchanged. No new model or scientific result is introduced.

## Reproduce the frozen analysis

Use `run_reproduction.sh` with the 20-input manifest. It downloads official NHANES XPT inputs, runs the R analysis and separate implementation, assembles the saved sensitivity presentation, and compares all 17 CSVs. Read the versioned analysis specification, execution history, package/session information and `docs/RESEARCH_HISTORY_ERRATA.md` first. This editing task does not rerun R or claim a new end-to-end reproduction.

## Reproduce IAOEH presentation figures

Install the fixed versions in `scripts/requirements_plot.txt`, then run `python3 scripts/plot_iaoeh.py`. It reads saved aggregates from `data/`, writes Fig1–Fig3 and FigS1–FigS4 in PNG/PDF/SVG/EPS to `figures/iaoeh/`, and records geometry and plotted rows in `evidence/`. It fits no model. Arial is used where installed; a missing font may change layout and should be reported rather than silently treated as byte-identical reproduction.

## Authorship and AI disclosure

Jiuxi Zhu (first and corresponding author, 320220908491@lzu.edu.cn): study coordination; critical assessment of study design and data integrity; original-draft preparation; interpretation, revision and integration of coauthors’ comments.

Yinlong Zuo (320220908521@lzu.edu.cn): substantive statistical review; verification of data and reported estimates; assessment of reproducibility and statistical tables and figures.

Yixiao Liu (liuyixiao2025@lzu.edu.cn): critical review of medical and epidemiological interpretation, literature and scientific arguments; substantive discussion revision.

Zhiyi Lin (linzhiyi2025@lzu.edu.cn): scientific supervision; critical evaluation of design, originality and conclusion validity; oversight of research integrity, academic quality and submission standards.

All four authors have confirmed completion of their assigned reviews and approval of the 56-reference manuscript.

Artificial intelligence tools were used solely to assist with data processing and literature organization. All statistical analyses, results verification, clinical interpretations, citations, and final manuscript text were reviewed and approved by the authors, who retain full responsibility for the integrity and accuracy of the work.

The analysis specification was finalized after exploratory inspection and is not prospective preregistration. Historical execution evidence is described in docs/RESEARCH_HISTORY_ERRATA.md.

## Version and rights

The versioned v1.0.2 release is https://github.com/zjx999999/nhanes-pfos-liver-stiffness/releases/tag/v1.0.2 . Its publication status and commit are established by the GitHub Release record. Historical v1.0.0 and v1.0.1 tags and release assets remain preserved. `LICENSE` applies to original project code; no participant-level XPT, credentials, private editorial audits or third-party full-text papers are distributed. See `docs/RELEASE_STATUS.md` and `docs/LICENSING_SCOPE.md`.
