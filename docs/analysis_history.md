# Analysis and publication history

- Exploratory later-period and initial cross-period results were inspected before the analysis specification was finalized. No prospective preregistration is claimed.
- The clinical expanded model retained age, sex, race/ethnicity, BMI, diabetes and alcohol category; the base model remains a separate adjustment tier. The covariate set was not selected for this GitHub release.
- Earlier technical corrections, including alcohol routing, VCTE percentage coding, viral marker coding, coefficient inference degrees of freedom and secondary multiplicity families, are recorded in the historical v1.3 specification. Both inference rules are retained.
- The analysis/review/independent_recalc.R script is a separate implementation of the primary models. Historical AI-assisted technical checks and the later author-reported review are distinct stages; the latest author-confirmed review scopes are recorded in AI_USE_AND_AUTHOR_REVIEW.md.
- A later presentation-only task split secondary and sensitivity plots into Figures 5 and 6. It added the descriptive coefficient-magnitude calculation using the same 1,323 cases; no regression was refitted.
- 2026-11-16: the public code package retained the historical main and separate recalculation code byte-for-byte and added explicit input-root orchestration. The manifest was expanded from 18 to 20 files to include two previously unlisted SMQ dependencies read by the code. This task performed input hash and syntax checks, not another model fit.

AI assistance and the scope of the earlier author-reported review are disclosed concisely in [AI_USE_AND_AUTHOR_REVIEW.md](AI_USE_AND_AUTHOR_REVIEW.md). The earlier analysis and execution history remains preserved.

See [RESEARCH_HISTORY_ERRATA.md](RESEARCH_HISTORY_ERRATA.md) for the subsequent 2026-11-16 execution audit, corrected comparison coverage and precise interpretation of historical review wording.

- Presentation consolidation: manuscript Table 2/3 become Supplementary Tables S11/S12, with the source CSVs retained unchanged. Figure 1 arrow channels, Figure 3 domain-marker spacing and table styling are presentation-only changes; no R model or result is changed.
