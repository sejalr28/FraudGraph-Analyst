# Data Dictionary — `fraud_sample.csv`

Source: [IEEE-CIS Fraud Detection](https://www.kaggle.com/c/ieee-fraud-detection) (Kaggle).
This file is a stratified sample of the full training set (590,540 rows) built by
`sql/build_db.py`'s upstream sampling step: all rows kept a slimmed, business-relevant
column set, and legitimate transactions were downsampled so the file is a manageable
43,737 rows at a realistic ~10% fraud rate (vs. ~3.5% in the raw data, which is too
sparse to explore quickly).

| Column | Description |
|---|---|
| `TransactionID` | Unique transaction identifier |
| `isFraud` | Target: 1 = confirmed fraud, 0 = legitimate |
| `TransactionDT` | Seconds offset from a reference timestamp (not a real calendar date) |
| `TransactionDate` / `TransactionHour` / `TransactionDayOfWeek` | Derived from `TransactionDT` assuming a reference start date, for time-of-day analysis |
| `TransactionAmt` | Transaction amount (USD) |
| `ProductCD` | Product category code (W, C, R, H, S) |
| `card1`–`card6` | Card/account identifiers and attributes (issuer, card type, category) |
| `addr1`, `addr2` | Billing address region codes |
| `dist1`, `dist2` | Distance features (e.g. billing vs. shipping address) |
| `P_emaildomain`, `R_emaildomain` | Purchaser / recipient email domain |
| `C1`–`C14` | Counting features (e.g. number of addresses associated with the card) — anonymized |
| `D1`–`D15` | Time-delta features (e.g. days since last transaction) — anonymized |
| `M1`–`M9` | Match flags (e.g. does billing name match card name) — anonymized |
| `DeviceType`, `DeviceInfo` | Device channel and device fingerprint string |
| `id_01`–`id_38` | Identity/behavioral features from device & network checks — anonymized |

Anonymized columns (`C*`, `D*`, `M*`, `id_*`) are provided by Kaggle without exact
definitions to protect proprietary fraud-model logic — this is standard for public
fraud datasets and doesn't block analysis; they're used as-is for aggregate patterns.
