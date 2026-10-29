# From risk-measures homework to a reproducible project

- Split risk definitions, acquisition and reporting into separate modules with no CRAN dependencies.
- Preserved dates and source metadata rather than discarding them after computing returns.
- Corrected the adjusted-close check: Yahoo column prefixes made the original literal "Adjusted" test unreliable.
- Defined all outputs on the positive-loss scale with explicit confidence, unit and horizon.
- Replaced threshold-based tail averaging with fractional empirical-tail ES, including tied observations.
- Added analytic Gaussian and fixed-df Student-t ES alongside VaR, and made the Monte Carlo normal assumption explicit.
- Added rolling, prior-only 252-return forecasts, coverage diagnostics and no-lookahead tests.
- Saved report tables, plots, source checksums, retrieval manifests and R session details.
- Documented index-construction/currency differences and the limits of binomial and ES diagnostics.
