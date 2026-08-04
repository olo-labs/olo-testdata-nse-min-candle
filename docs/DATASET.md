# Dataset overview

## Plain-language description

This repository is a date-partitioned collection of one-minute open, high, low, close, and volume (OHLCV) candles for instruments associated with India's National Stock Exchange. Stock-like instruments and indices are separated into two directories. Files remain compressed for practical cloning and storage.

## Verified snapshot

The following inventory was measured from the repository on 4 August 2026:

| Property | `Minute/NSE` | `Minute/NSE_IDX` |
|---|---:|---:|
| Earliest archive date | 2024-11-25 | 2024-11-25 |
| Latest archive date | 2026-08-03 | 2026-08-03 |
| ZIP archives | 419 | 419 |
| Compressed size | 2.32 GiB | 0.23 GiB |
| Files per archive | 1 | 1 |

Coverage is not the same as a completeness guarantee. The inclusive date range contains weekends, holidays, and possibly dates without an archive. Consumers should enumerate actual files rather than generate an assumed business-day calendar.

## Dataset unit

One logical observation is a candle identified by `Ticker + Date + Time`. It describes the observed open, high, low, close, volume, and open-interest values for that instrument and timestamp.

The archive is the physical date partition. The CSV inside an archive contains many tickers for that date; it is not one file per ticker.

## Terminology

- **OHLC:** open, high, low, and close prices within an interval.
- **OHLCV:** OHLC plus traded volume.
- **One-minute candle:** a summary associated with a minute-level timestamp. The files do not formally document whether timestamps mark the beginning or end of an interval.
- **Ticker:** the provider's instrument identifier, often with dot-delimited suffixes such as `.NSE` or `.NSE_IDX`.
- **Delivery data:** in Indian-market usage, this often means deliverable quantity or delivery percentage. Those fields are not present here.

## Intended uses

Suitable uses include education, reproducible research, prototyping, backtesting after validation, visualization, and feature generation. The data is not an exchange-certified live feed and should not be treated as authoritative order, trade, or corporate-action data.

## Versioning

The repository does not currently publish formal dataset releases. For reproducibility, record the Git commit hash used in an analysis:

```bash
git rev-parse HEAD
```

Also retain the archive path and a content checksum for critical research.
