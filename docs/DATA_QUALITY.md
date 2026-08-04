# Data quality and validation

## Checks recommended before use

1. Confirm the ZIP opens and contains exactly one CSV member.
2. Match the nine expected headers, allowing only documented variations.
3. Parse archive and row dates using explicit day-first formats.
4. Confirm row dates match the archive date.
5. Check uniqueness of `Ticker + Date + Time`.
6. Verify `High >= Open, Close, Low` and `Low <= Open, Close, High`.
7. Check for negative prices, volume, or open interest.
8. Measure missing minutes per ticker against the appropriate trading session.
9. Detect discontinuities around corporate actions and symbol changes.
10. Record file hashes and the Git commit for reproducibility.

## Missing rows

Thinly traded instruments need not have a candle for every clock minute. A missing observation is therefore different from a candle with zero volume. Do not forward-fill OHLC or replace absent volume with zero without making that modeling choice explicit.

## Price adjustments

No adjustment flag or factor is included. Splits, dividends, mergers, and other corporate actions may create discontinuities. Obtain an independent corporate-action source before calculating long-horizon returns.

## Trading sessions

Do not hard-code a single session window for every ticker. Auctions, special sessions, instrument categories, and exchange changes can produce timestamps outside an assumed regular equity session.

## Survivorship and symbol mapping

The dataset is organized by daily observations rather than a point-in-time security master. Building a current-symbol list and applying it backward can introduce survivorship bias. Preserve the raw ticker and join against dated reference data where possible.

## Report a problem

Open a GitHub issue with the archive path, ticker, timestamp, expected result, observed result, validation method, and repository commit. Avoid attaching a repackaged large archive when a few representative rows and a checksum are sufficient.
