# Latest NSE India One-Minute OHLCV Data

Updated on **{{DATE}} at {{TIME}} UTC**.

This rolling release contains the latest consolidated NSE one-minute OHLCV
dataset produced from repository commit `{{SHORT_COMMIT}}`.

## Release trigger

`{{COMMIT_MESSAGE}}`

## Package summary

- **NSE stock archive parts:** {{NSE_PARTS}}
- **NSE index archive parts:** {{INDEX_PARTS}}
- **Total data archive assets:** {{ASSET_COUNT}}
- **Source commit:** `{{COMMIT}}`

## Archive assets

| Asset | Dataset | Daily source ZIPs | Size |
|---|---|---:|---:|
{{ASSET_TABLE}}

## Archive structure

NSE stock and other exchange-traded instrument data is packaged separately from
NSE index data.

```text
NSE-Minute-part-001.zip
NSE-Minute-part-002.zip
...

NSE-Index-Minute-part-001.zip
...