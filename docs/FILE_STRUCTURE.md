# File and directory structure

## Directory meanings

| Directory | Meaning |
|---|---|
| `Minute/NSE/` | Daily minute candles for stock and other exchange-traded instrument tickers carrying the `.NSE` suffix |
| `Minute/NSE_IDX/` | Daily minute candles for index tickers carrying the `.NSE_IDX` suffix |

Do not infer the exact security type solely from the top-level directory. Some ticker strings include additional provider-specific series or instrument codes.

## Archive naming convention

```text
Minute/<DATASET>/<DDMMYYYY>.zip
```

`03082026.zip` means 3 August 2026, not 8 March 2026. Always parse with `%d%m%Y`.

## CSV member naming

| Dataset | Observed pattern | Example |
|---|---|---|
| NSE | `GFDLCM_STOCK_DDMMYYYY.CSV` | `GFDLCM_STOCK_01012025.CSV` |
| NSE indices | `GFDLCM_INDICES_DDMMYYYY.csv` | `GFDLCM_INDICES_01012025.csv` |

ZIP member extension capitalization is not guaranteed. Use a case-insensitive `.csv` check and inspect the archive rather than constructing a member name.

## CSV format

- comma delimiter;
- first row is a header;
- nine columns in a stable observed order;
- one date per daily archive in sampled files;
- no declared timezone, currency, adjustment status, or text encoding metadata;
- numeric prices can appear as integers or decimals.

Robust consumers should match columns by header name, not position, and should reject unexpected extra members rather than silently selecting one.

## Programmatic discovery

Python example for chronological archive enumeration:

```python
from datetime import datetime
from pathlib import Path

files = sorted(
    Path("Minute/NSE").glob("*.zip"),
    key=lambda p: datetime.strptime(p.stem, "%d%m%Y"),
)
print(files[0], files[-1])
```

Lexicographic filename sorting is incorrect because the filename begins with day, not year.
