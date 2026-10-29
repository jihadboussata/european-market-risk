# Market data

`python scripts/download_prices.py` requests Yahoo Finance chart data for ^FCHI (CAC40), ^GDAXI (DAX), ^SSMI (SMI) and ^FTSE (FTSE100), over 2015-01-01 ≤ date < 2026-01-01. It writes `data/raw/index_prices.csv` with `date,index,close` and a neighboring `.manifest.json`.

The field named close in the normalized file contains adjusted close when the endpoint provides usable data, otherwise the explicitly recorded close fallback. Both files should be kept together. The analysis copies the manifest into results; raw prices stay local and are git-ignored. The source dataset can be revised or become unavailable. No market data is invented to compensate for failed requests.

The committed results/data_manifest.json identifies the snapshot used for the published analysis. Use the exact downloaded CSV and check its SHA-256 against that manifest for input-level reproducibility. Source vendor terms govern raw-data use and redistribution; the repository's MIT code license does not apply to vendor prices.
