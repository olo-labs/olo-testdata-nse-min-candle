# Latest NSE India One-Minute OHLCV Data

Updated on **{{DATE}} at {{TIME}} UTC**.

This rolling release contains the latest consolidated NSE one-minute OHLCV
dataset produced from repository commit `{{SHORT_COMMIT}}`.

## Release trigger

`{{COMMIT_MESSAGE}}`

## Package summary

* **NSE stock archive parts:** {{NSE_PARTS}}
* **NSE index archive parts:** {{INDEX_PARTS}}
* **Total data archive assets:** {{ASSET_COUNT}}
* **Source commit:** `{{COMMIT}}`

## Archive assets

| Asset           | Dataset | Daily source ZIPs | Size |
| --------------- | ------- | ----------------: | ---: |
| {{ASSET_TABLE}} |         |                   |      |

## Archive structure

NSE stock and other exchange-traded instrument data is packaged separately from
NSE index data.

```text
NSE-Minute-part-001.zip
NSE-Minute-part-002.zip
...

NSE-Index-Minute-part-001.zip
...
```

Every daily source ZIP is extracted before the consolidated archives are
created.

The published release archives contain CSV files directly rather than nested
daily ZIP files.

Each generated archive is kept below the configured GitHub release-asset size
limit.

## Additional release assets

The release also includes:

* `RELEASE_MANIFEST.json`
* `SHA256SUMS.txt`
* `RELEASE_NOTES.md`
* `LICENSE`

`RELEASE_MANIFEST.json` records:

* Dataset name
* Archive part number
* Archive filename
* Compressed size
* Uncompressed size
* SHA-256 checksum
* Source daily ZIP count
* First source archive
* Last source archive

Use `SHA256SUMS.txt` to verify downloaded archive integrity.

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

## Data interpretation

The source files do not explicitly declare a timezone. Confirm the upstream
timestamp convention before assigning a timezone.

Prices are not adjusted for stock splits, dividends, bonus issues, rights
issues, or other corporate actions unless independently verified.

The absence of a candle does not necessarily indicate zero trading activity. An
instrument may not trade during every minute.

Index volume and open-interest values may be zero in the source data.

## Rolling release behavior

This release is updated when:

* A commit pushed to the configured branch has a message beginning exactly with
  `RC:`, or
* The rolling-release workflow is run manually with `force_release` enabled.

The rolling release tag is:

```text
nse-minute-latest
```

The tag is moved to the current release commit whenever the workflow runs
successfully.

Existing release assets are removed and replaced. This also removes obsolete
archive parts when the number of NSE or index archives changes.

## License and data rights

Repository code, documentation, and original project content are provided under
the Apache License 2.0.

The project license does not grant ownership of, or additional rights over, the
underlying market data. Users are responsible for reviewing applicable upstream
data terms and local requirements before using or redistributing the dataset.

## Disclaimer

This is an independent community project. It is not affiliated with, endorsed
by, or operated by the National Stock Exchange of India.

The dataset is supplied without warranty and is not investment advice.
