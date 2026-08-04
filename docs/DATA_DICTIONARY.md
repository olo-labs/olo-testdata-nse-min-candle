# OHLCV data dictionary

The header observed in both datasets is:

```csv
Ticker,Date,Time,Open,High,Low,Close,Volume,Open Interest
```

| Column | Recommended type | Format / unit | Meaning |
|---|---|---|---|
| `Ticker` | string | provider-specific identifier | Instrument symbol, including exchange/category suffix |
| `Date` | date | `DD/MM/YYYY` | Calendar date associated with the candle |
| `Time` | time | `HH:MM:SS` | Source-provided intraday timestamp |
| `Open` | decimal/float | price units not declared | First price represented by the candle |
| `High` | decimal/float | price units not declared | Highest price represented by the candle |
| `Low` | decimal/float | price units not declared | Lowest price represented by the candle |
| `Close` | decimal/float | price units not declared | Last price represented by the candle |
| `Volume` | integer | units/contracts not declared | Source-provided traded volume |
| `Open Interest` | integer | units/contracts not declared | Source-provided open interest |

## Recommended canonical schema

For analytics, normalize to these names and types while preserving raw values:

```text
ticker          UTF-8 string, non-null
timestamp_raw   timestamp without timezone
open            decimal or float64
high            decimal or float64
low             decimal or float64
close           decimal or float64
volume          int64
open_interest   int64
source_file     UTF-8 string
```

Keep `source_file` for lineage. If exact decimal arithmetic matters, inspect the maximum scale across the corpus and select a sufficiently wide decimal type instead of binary floating point.

## Identifier examples

- `1003IIFL29.NC.NSE` is an observed NSE ticker with provider-specific components.
- `BHARATBOND-APR25.NSE_IDX` is an observed index-dataset ticker.

Do not strip suffixes until a symbol-master mapping establishes their meaning. Ticker renames, series changes, expiries, and corporate actions can make a ticker an unstable long-term entity identifier.

## Timestamp handling

Combine date and time explicitly:

```python
df["timestamp_raw"] = pd.to_datetime(
    df["Date"] + " " + df["Time"],
    format="%d/%m/%Y %H:%M:%S",
    errors="raise",
)
```

The source contains no timezone field. Avoid attaching `Asia/Kolkata` as a fact unless separately validated. If your project adopts that convention, document it as a pipeline assumption.

## Fields not included

The schema has no adjusted price, VWAP, trade count, bid/ask, security name, ISIN, sector, corporate action, deliverable quantity, or delivery-percentage column.
