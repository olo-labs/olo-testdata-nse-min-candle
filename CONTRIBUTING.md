# Contributing

Contributions that improve coverage, documentation, validation, or reproducibility are welcome.

## Before opening a change

- Keep source archives immutable unless correcting a demonstrated data issue.
- Do not rename historic archives without discussing the migration first.
- Never commit credentials, private feeds, or data you lack permission to redistribute.
- Keep examples deterministic and avoid implying that a strategy is profitable.
- Update the inventory statements in the README and `docs/DATASET.md` when adding dates.

## Adding daily archives

1. Place stock data in `Minute/NSE/DDMMYYYY.zip` and index data in `Minute/NSE_IDX/DDMMYYYY.zip`.
2. Include exactly one CSV member in each ZIP.
3. Preserve the expected nine-column header.
4. Confirm the archive date, member date, and all row dates agree.
5. Run the quality checks described in `docs/DATA_QUALITY.md`.
6. State provenance, checksums, coverage, and validation results in the pull request.

## Reporting data-quality issues

Include:

- repository commit hash;
- archive and internal CSV path;
- ticker and timestamp;
- minimal representative rows;
- expected and observed behavior;
- the command or code used to detect the issue.

## Documentation style

Use precise terms such as “one-minute OHLCV candles” and expand abbreviations on first use. Add descriptive headings and runnable examples. Do not call `Volume` “delivery volume”: the dataset contains no such definition.
