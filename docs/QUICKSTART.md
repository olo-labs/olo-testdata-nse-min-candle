# Quick-start recipes

## Load one archive with pandas

```python
import pandas as pd

df = pd.read_csv("Minute/NSE/03082026.zip")
df.columns = [c.lower().replace(" ", "_") for c in df.columns]
df["timestamp"] = pd.to_datetime(
    df.pop("date") + " " + df.pop("time"),
    format="%d/%m/%Y %H:%M:%S",
)
```

## Load a date range without extracting files

```python
from datetime import datetime
from pathlib import Path
import pandas as pd

def archive_date(path: Path):
    return datetime.strptime(path.stem, "%d%m%Y").date()

start = datetime.strptime("2026-07-01", "%Y-%m-%d").date()
end = datetime.strptime("2026-07-31", "%Y-%m-%d").date()

paths = [
    p for p in Path("Minute/NSE").glob("*.zip")
    if start <= archive_date(p) <= end
]
frames = [pd.read_csv(p).assign(source_file=str(p)) for p in paths]
july = pd.concat(frames, ignore_index=True)
```

This can require substantial memory. For larger scans, filter one archive at a time and write a partitioned Parquet dataset.

## Filter a symbol while streaming daily files

```python
from pathlib import Path
import pandas as pd

matches = []
for path in Path("Minute/NSE").glob("*.zip"):
    day = pd.read_csv(path)
    selected = day.loc[day["Ticker"] == "YOUR_TICKER.NSE"]
    if not selected.empty:
        matches.append(selected)

history = pd.concat(matches, ignore_index=True)
```

Inspect actual ticker values first; do not assume the provider's ticker exactly matches an exchange display symbol.

## Query extracted CSVs with DuckDB

DuckDB does not consistently scan CSV members inside many ZIP files directly. Extract selected members to a temporary directory, then query:

```sql
SELECT
  Ticker,
  strptime(Date || ' ' || Time, '%d/%m/%Y %H:%M:%S') AS timestamp,
  Open, High, Low, Close, Volume
FROM read_csv_auto('extracted/*.csv', union_by_name = true)
WHERE Ticker = 'YOUR_TICKER.NSE'
ORDER BY timestamp;
```

## Resample to five-minute candles

```python
candles_5m = (
    history.set_index("timestamp")
    .groupby("Ticker")
    .resample("5min")
    .agg({
        "Open": "first",
        "High": "max",
        "Low": "min",
        "Close": "last",
        "Volume": "sum",
        "Open Interest": "last",
    })
    .dropna(subset=["Open"])
)
```

Confirm whether the source timestamps denote interval starts or ends before aligning resampled bars.

## Minimal integrity checks

```python
key = ["Ticker", "Date", "Time"]
assert not df[key].isna().any().any()
assert not df.duplicated(key).any()
assert (df["High"] >= df[["Open", "Close", "Low"]].max(axis=1)).all()
assert (df["Low"] <= df[["Open", "Close", "High"]].min(axis=1)).all()
assert (df[["Volume", "Open Interest"]] >= 0).all().all()
```

Assertions describe common OHLC expectations; investigate exceptions rather than deleting them automatically.
