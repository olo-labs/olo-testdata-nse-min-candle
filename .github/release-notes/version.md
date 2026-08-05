# NSE India One-Minute OHLCV Historical Data {{VERSION}}

Released on **{{DATE}} at {{TIME}} UTC**.

This versioned release packages the NSE one-minute OHLCV dataset from repository
commit `{{SHORT_COMMIT}}`.

## Package summary

* **Version:** {{VERSION}}
* **NSE stock archive parts:** {{NSE_PARTS}}
* **NSE index archive parts:** {{INDEX_PARTS}}
* **Total data archive assets:** {{ASSET_COUNT}}
* **Source commit:** `{{COMMIT}}`

## Archive assets

| Asset           | Dataset | Daily source ZIPs | Size |
| --------------- | ------- | ----------------: | ---: |
{{ASSET_TABLE}}

## Archive structure

NSE stock data and NSE index data are published separately:

```text
NSE-Minute-part-001.zip
NSE-Minute-part-002.zip
...

NSE-Index-Minute-part-001.zip
...
```

All daily ZIP files stored in the repository are extracted during packaging.

The consolidated release archives contain CSV files directly rather than nested
daily ZIP archives.

Every individual release archive is kept below the configured 2 GiB release
asset limit.

## Dataset contents

Each normal one-minute candle row contains:

* Ticker
* Date
* Time
* Open
* High
* Low
* Close
* Volume
* Open interest

## Additional release assets

* `RELEASE_MANIFEST.json`
* `SHA256SUMS.txt`
* `RELEASE_NOTES-{{VERSION}}.md`
* `LICENSE`

Use `SHA256SUMS.txt` to verify downloaded release assets.

The manifest records the archive filename, dataset, part number, size, checksum,
source archive count, and source archive range for every generated data asset.

## Data interpretation

The source files do not explicitly declare a timezone. Confirm the upstream
timestamp convention before assigning a timezone.

Prices are not adjusted for stock splits, dividends, bonus issues, rights
issues, or other corporate actions unless independently verified.

Absence of a candle does not necessarily represent zero trading activity. An
instrument may not trade during every minute.

Index volume and open-interest values may be zero in the source data.

## License and data rights

Repository code, documentation, and original project content are provided under
the Apache License 2.0.

The project license does not grant ownership of, or additional rights over, the
underlying market data. Users are responsible for reviewing any applicable
upstream data terms and local requirements before using or redistributing the
dataset.

## Disclaimer

This is an independent community project. It is not affiliated with, endorsed
by, or operated by the National Stock Exchange of India.

The dataset is supplied without warranty and is not investment advice.
