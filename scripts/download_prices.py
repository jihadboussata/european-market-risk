"""Download the original four Yahoo index series; preserve dates and provenance."""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import urllib.parse
import urllib.request

TICKERS = {"CAC40": "^FCHI", "DAX": "^GDAXI", "SMI": "^SSMI", "FTSE": "^FTSE"}


def fetch(output, start="2015-01-01", end="2026-01-01"):
    # Yahoo period2 is exclusive; no observations from 2026 enter this study.
    p1 = int(datetime.fromisoformat(start).replace(tzinfo=timezone.utc).timestamp())
    p2 = int(datetime.fromisoformat(end).replace(tzinfo=timezone.utc).timestamp())
    if p2 <= p1: raise ValueError("End date must be later than start date.")
    rows, sources = [], []
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    for name, ticker in TICKERS.items():
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{urllib.parse.quote(ticker, safe='')}?period1={p1}&period2={p2}&interval=1d"
        request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(request, timeout=90) as response: payload = response.read()
        result = json.loads(payload)["chart"]["result"][0]
        indicators = result["indicators"]
        adjusted = indicators.get("adjclose", [{}])[0].get("adjclose")
        closes = indicators["quote"][0]["close"]
        usable_adjusted = adjusted is not None and len(adjusted) == len(closes) and all(
            close is None or (adj is not None and math.isfinite(adj) and adj > 0)
            for close, adj in zip(closes, adjusted or []))
        values = adjusted if usable_adjusted else closes
        field = "adjusted_close" if usable_adjusted else "close"
        n = 0
        seen = set()
        for timestamp, value in zip(result["timestamp"], values):
            date = datetime.fromtimestamp(timestamp, timezone.utc).date().isoformat()
            if value is None or not math.isfinite(value) or value <= 0 or not start <= date < end: continue
            if date in seen: raise ValueError(f"Duplicate date for {name}: {date}")
            seen.add(date)
            rows.append({"date": date, "index": name, "close": format(value, ".12g")})
            n += 1
        sources.append({"index": name, "ticker": ticker, "url": url, "selected_field": field,
            "currency": result["meta"].get("currency"), "prices": n,
            "response_sha256": hashlib.sha256(payload).hexdigest()})
        print(f"{name}: {n} observations; {field}", flush=True)
    rows.sort(key=lambda row: (row["index"], row["date"]))
    with output.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["date", "index", "close"])
        writer.writeheader(); writer.writerows(rows)
    manifest = {"source": "Yahoo Finance chart endpoint", "start_inclusive": start, "end_exclusive": end,
        "retrieved_utc": datetime.now(timezone.utc).isoformat(), "series": sources,
        "csv_sha256": hashlib.sha256(output.read_bytes()).hexdigest()}
    output.with_suffix(".manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("data/raw/index_prices.csv"))
    parser.add_argument("--start", default="2015-01-01")
    parser.add_argument("--end", default="2026-01-01")
    args = parser.parse_args()
    fetch(args.output, args.start, args.end)
