# NSE India 1-Minute OHLCV Historical Market Data

Open, downloadable **National Stock Exchange of India (NSE) one-minute candle data** for stocks and indices. The repository keeps daily CSV files in ZIP archives so researchers, developers, students, and quantitative analysts can obtain Indian market OHLCV data from one place.

> **Current verified coverage:** 25 November 2024 through 3 August 2026 · 419 daily archives per dataset · approximately 2.55 GB compressed

## What is in this repository?

| Dataset | Path | Instruments | Archive count | Compressed size |
|---|---|---|---:|---:|
| NSE stocks and other exchange-traded instruments | [`Minute/NSE`](Minute/NSE) | Tickers ending in `.NSE` | 419 | 2.32 GiB |
| NSE indices | [`Minute/NSE_IDX`](Minute/NSE_IDX) | Tickers ending in `.NSE_IDX` | 419 | 0.23 GiB |

Every archive represents one date and contains one comma-separated file. Each row is a one-minute OHLC candle with ticker, date, time, open, high, low, close, volume, and open interest.

This dataset is useful for:

- backtesting Indian equity and index trading strategies;
- market microstructure and intraday volatility research;
- technical-indicator, charting, and screening applications;
- machine-learning feature engineering and time-series experiments;
- reproducible examples that need historical NSE minute candles.

## Data structure

```text
olo-testdata-nse-min-candle/
├── Minute/
│   ├── NSE/
│   │   ├── 25112024.zip
│   │   ├── ...
│   │   └── 03082026.zip
│   └── NSE_IDX/
│       ├── 25112024.zip
│       ├── ...
│       └── 03082026.zip
├── docs/
├── CITATION.cff
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

Archive names use `DDMMYYYY.zip`. Their CSV members use these patterns:

- stocks: `GFDLCM_STOCK_DDMMYYYY.CSV` (extension case varies);
- indices: `GFDLCM_INDICES_DDMMYYYY.csv`.

Example stock row:

```csv
Ticker,Date,Time,Open,High,Low,Close,Volume,Open Interest
1003IIFL29.NC.NSE,01/01/2025,10:48:59,975,975,975,975,9,0
```

Read the [complete data dictionary](docs/DATA_DICTIONARY.md) and [file-layout specification](docs/FILE_STRUCTURE.md) before building production pipelines.

## Quick start

Clone the repository (Git LFS may be required if your checkout stores archives as LFS objects):

```bash
git clone https://github.com/olo-labs/olo-testdata-nse-min-candle.git
cd olo-testdata-nse-min-candle
```

### Python and pandas

Pandas can read the single CSV directly from a ZIP:

```python
import pandas as pd

path = "Minute/NSE/03082026.zip"
df = pd.read_csv(path)
df["timestamp"] = pd.to_datetime(
    df["Date"] + " " + df["Time"],
    format="%d/%m/%Y %H:%M:%S",
)

reliance = df.loc[df["Ticker"].str.startswith("RELIANCE")]
print(reliance.head())
```

Use an explicit member when a library cannot infer the CSV:

```python
from zipfile import ZipFile
import pandas as pd

with ZipFile("Minute/NSE_IDX/03082026.zip") as archive:
    member = archive.namelist()[0]
    with archive.open(member) as csv_file:
        indices = pd.read_csv(csv_file)
```

### Polars

```python
from io import BytesIO
from zipfile import ZipFile
import polars as pl

with ZipFile("Minute/NSE/03082026.zip") as archive:
    frame = pl.read_csv(BytesIO(archive.read(archive.namelist()[0])))
```

See [quick-start recipes](docs/QUICKSTART.md) for multi-day loading, symbol filtering, DuckDB, validation, and resampling.

## Important interpretation notes

- `Date` is `DD/MM/YYYY`; do not rely on locale-based automatic parsing.
- Observed minute timestamps commonly end in `:59`. Treat the stored value as the source timestamp; do not silently round it.
- The files do not declare a timezone. Indian NSE trading times normally use India Standard Time, but consumers should only localize timestamps after confirming the upstream convention for their use case.
- Prices are unadjusted unless independently verified. Corporate-action adjustment factors are not included.
- Not every instrument trades in every minute. Absence of a row is not automatically a zero-volume candle.
- Index `Volume` and `Open Interest` are commonly zero in sampled files.
- This is **market OHLCV data**, not NSE security-wise delivery quantity or delivery-percentage data. No delivery-specific column exists in the published schema.

## Data quality and limitations

The repository redistributes historical test data as provided and does not guarantee completeness, accuracy, exchange certification, survivorship-bias handling, or fitness for live trading. Validate dates, duplicates, price relationships, missing intervals, symbol changes, and corporate actions before analysis. Do not use this dataset alone for investment decisions.

See [data quality guidance](docs/DATA_QUALITY.md) and the [FAQ](docs/FAQ.md).

## Documentation

- [Dataset overview and terminology](docs/DATASET.md)
- [File and directory structure](docs/FILE_STRUCTURE.md)
- [Column-level data dictionary](docs/DATA_DICTIONARY.md)
- [Python, Polars, and DuckDB recipes](docs/QUICKSTART.md)
- [Quality checks and known limitations](docs/DATA_QUALITY.md)
- [Frequently asked questions](docs/FAQ.md)
- [How to contribute](CONTRIBUTING.md)

## Citation and license

If this repository supports research, cite it using [`CITATION.cff`](CITATION.cff). Code, documentation, and repository contents are provided under the [Apache License 2.0](LICENSE). Users are responsible for checking whether any upstream market-data terms or local rules apply to their intended use and redistribution.

## Search terms

NSE historical data, NSE minute data, NSE intraday data, Indian stock market dataset, one-minute OHLC, OHLCV CSV, NIFTY historical minute data, NSE index candles, algorithmic trading dataset, quantitative finance India, stock market backtesting data.
