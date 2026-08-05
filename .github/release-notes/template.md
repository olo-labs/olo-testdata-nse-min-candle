# NSE India One-Minute OHLCV Historical Data {{VERSION}}

Released on **{{DATE}} at {{TIME}} UTC**.

This versioned release packages the NSE one-minute OHLCV dataset from repository
commit `{{SHORT_COMMIT}}`.

## Package summary

- **Version:** {{VERSION}}
- **NSE stock archive parts:** {{NSE_PARTS}}
- **NSE index archive parts:** {{INDEX_PARTS}}
- **Total data archive assets:** {{ASSET_COUNT}}
- **Source commit:** `{{COMMIT}}`

## Archive assets

| Asset | Dataset | Daily source ZIPs | Size |
|---|---|---:|---:|
{{ASSET_TABLE}}

## Archive structure

NSE stock data and NSE index data are published separately:

```text
NSE-Minute-part-001.zip
NSE-Minute-part-002.zip
...

NSE-Index-Minute-part-001.zip
...