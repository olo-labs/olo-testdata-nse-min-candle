# Frequently asked questions

## Is this free NSE historical minute data?

The repository is publicly accessible and licensed under Apache-2.0. Market data can also be subject to upstream rights, exchange terms, or jurisdiction-specific rules. Review those obligations for your use case.

## Does it contain NIFTY and other NSE index history?

Index-series observations are stored in `Minute/NSE_IDX`. Enumerate the `Ticker` column to discover the identifiers available on a particular date; the repository does not currently include a master list mapping tickers to official index names.

## Is this tick-by-tick data?

No. Rows are minute-level OHLC observations, not individual trades, quotes, or order-book events.

## Is this bhavcopy data?

No. A bhavcopy is generally an end-of-day exchange file. This repository contains intraday minute candles.

## Does it include NSE delivery volume or delivery percentage?

No delivery-specific field is present. `Volume` is not documented as deliverable quantity and must not be relabeled as delivery volume.

## Are prices adjusted for splits and dividends?

No adjustment metadata is included, so treat prices as unadjusted until independently verified.

## What timezone are timestamps in?

The CSV does not declare one. NSE trading is normally discussed in India Standard Time, but localization remains a consumer assumption unless verified against the upstream data specification.

## Why do many timestamps end in 59 seconds?

That pattern is present in sampled files. Preserve the source value. It may reflect the provider's candle-label convention, but the repository does not contain an authoritative interval-boundary definition.

## Why are index volume and open interest often zero?

Indices are calculated values rather than directly traded securities. Sampled index files commonly contain zeros. Do not assume the same behavior for every series without checking.

## Can I use this for live trading?

The repository is historical test data, not a real-time feed. Validate it independently and do not rely on it alone for financial decisions or order execution.

## How should I cite a particular version?

Use the metadata in `CITATION.cff` and add the exact Git commit hash and access date to make the dataset snapshot reproducible.
