# Reproducibility

Analysis environment: R 4.5.3, survey 4.5, haven 2.5.5; see analysis/reproducibility/sessionInfo.txt. The specification followed exploratory inspection. Read docs/RESEARCH_HISTORY_ERRATA.md for the actual execution history and limits of independent-code checks.

1. Verify this source snapshot with `python3 scripts/verify_payload.py`.
2. Obtain the 20 official CDC XPT files using `python3 scripts/fetch_data.py`; the manifest records URLs, sizes and SHA-256. Keep inputs in input_data/ or set NHANES_DATA_ROOT.
3. To rerun the frozen analysis, execute `bash run_reproduction.sh`. It runs main_analysis.R, the separate recalculation, deterministic sensitivity assembly and all 17 CSV comparisons. This requires the recorded R environment; no new R execution is claimed for this release-preparation task.
4. Install the versions in scripts/requirements_plot.txt and execute `python3 scripts/plot_iaoeh.py`. Seven IAOEH figures are written into figures/iaoeh/. The preparation task ran this entry in the existing project environment; all seven PNGs matched the prior figures byte-for-byte. No regression was refitted.

Original releases v1.0.0 and v1.0.1 remain preserved. The v1.0.1 technical update adds browsable source, 17-output validation, clarified execution/review history, author-confirmed review scopes and the IAOEH presentation entry. The owner-selected MIT License covers original project code, not CDC data, dependencies or third-party papers. No participant-level XPT or full-text papers are included.

## Final submission metadata synchronization

Authors (in order): Jiuxi Zhu, Yinlong Zuo, Yixiao Liu and Zhiyi Lin. All authors: Lanzhou University, Lanzhou, Gansu, China. First and corresponding author: Jiuxi Zhu; 320220908491@lzu.edu.cn.

All four authors have confirmed completion of their assigned reviews and approval of the 56-reference manuscript. Complete contributions are recorded in docs/AI_USE_AND_AUTHOR_REVIEW.md.

Artificial intelligence tools were used solely to assist with data processing and literature organization. All statistical analyses, results verification, clinical interpretations, citations, and final manuscript text were reviewed and approved by the authors, who retain full responsibility for the integrity and accuracy of the work.

The v1.0.2 update changes documentation for authorship and disclosure only. All existing statistical and plotting code, the 17 frozen statistical CSVs and seven committed figure PNGs remain byte-identical to v1.0.1. Frozen statistical results retain the v1.0.0 values. The versioned release is https://github.com/zjx999999/nhanes-pfos-liver-stiffness/releases/tag/v1.0.2.
