-- FraudGraph Analyst — Core SQL Analysis
-- Run against data/fraudgraph.db (SQLite). Build it first with: python sql/build_db.py
-- Each query answers a specific business question a fraud/risk analyst would be asked.

-- =========================================================
-- 1. Headline fraud KPIs
-- =========================================================
SELECT
    COUNT(*)                                            AS total_transactions,
    SUM(isFraud)                                         AS fraud_transactions,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2)             AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN isFraud = 1 THEN TransactionAmt END), 2) AS fraud_amount_usd,
    ROUND(SUM(TransactionAmt), 2)                         AS total_amount_usd,
    ROUND(100.0 * SUM(CASE WHEN isFraud = 1 THEN TransactionAmt END) / SUM(TransactionAmt), 2) AS pct_dollars_at_risk
FROM transactions;

-- =========================================================
-- 2. Fraud rate & dollar exposure by product category
-- =========================================================
SELECT
    ProductCD,
    COUNT(*)                                              AS n_transactions,
    SUM(isFraud)                                          AS n_fraud,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2)              AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN isFraud = 1 THEN TransactionAmt END), 2) AS fraud_amount_usd
FROM transactions
GROUP BY ProductCD
ORDER BY fraud_rate_pct DESC;

-- =========================================================
-- 3. Fraud rate by device type
-- =========================================================
SELECT
    COALESCE(DeviceType, 'unknown') AS device_type,
    COUNT(*)                        AS n_transactions,
    SUM(isFraud)                    AS n_fraud,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY device_type
ORDER BY fraud_rate_pct DESC;

-- =========================================================
-- 4. Fraud rate by hour of day (time-of-day risk pattern)
-- =========================================================
SELECT
    TransactionHour,
    COUNT(*)                        AS n_transactions,
    SUM(isFraud)                    AS n_fraud,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY TransactionHour
ORDER BY TransactionHour;

-- =========================================================
-- 5. Fraud rate by day of week
-- =========================================================
SELECT
    TransactionDayOfWeek,
    COUNT(*)                        AS n_transactions,
    SUM(isFraud)                    AS n_fraud,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY TransactionDayOfWeek
ORDER BY fraud_rate_pct DESC;

-- =========================================================
-- 6. Transaction amount profile: fraud vs legitimate
-- =========================================================
SELECT
    isFraud,
    COUNT(*)                       AS n_transactions,
    ROUND(AVG(TransactionAmt), 2)  AS avg_amount,
    ROUND(MIN(TransactionAmt), 2)  AS min_amount,
    ROUND(MAX(TransactionAmt), 2)  AS max_amount
FROM transactions
GROUP BY isFraud;

-- =========================================================
-- 7. High-risk email domains (P_emaildomain) — top 10 by fraud rate
--    (min 20 transactions to avoid noisy small samples)
-- =========================================================
SELECT
    P_emaildomain,
    COUNT(*)                        AS n_transactions,
    SUM(isFraud)                    AS n_fraud,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
WHERE P_emaildomain IS NOT NULL
GROUP BY P_emaildomain
HAVING COUNT(*) >= 20
ORDER BY fraud_rate_pct DESC
LIMIT 10;

-- =========================================================
-- 8. Card accounts (card1) with repeated fraud — velocity signal
--    Analysts flag accounts reused across multiple fraud incidents
-- =========================================================
SELECT
    card1,
    COUNT(*)                        AS n_transactions,
    SUM(isFraud)                    AS n_fraud,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY card1
HAVING SUM(isFraud) >= 2
ORDER BY n_fraud DESC
LIMIT 20;

-- =========================================================
-- 9. Devices shared across multiple distinct card accounts
--    (a classic fraud-ring signal: one device, many "different" payers)
-- =========================================================
SELECT
    DeviceInfo,
    COUNT(DISTINCT card1)           AS distinct_cards,
    COUNT(*)                        AS n_transactions,
    SUM(isFraud)                    AS n_fraud,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
WHERE DeviceInfo IS NOT NULL
GROUP BY DeviceInfo
HAVING COUNT(DISTINCT card1) >= 3
ORDER BY distinct_cards DESC
LIMIT 20;

-- =========================================================
-- 10. Billing addresses (addr1) shared across many cards — same signal, different entity
-- =========================================================
SELECT
    addr1,
    COUNT(DISTINCT card1)           AS distinct_cards,
    COUNT(*)                        AS n_transactions,
    SUM(isFraud)                    AS n_fraud,
    ROUND(100.0 * SUM(isFraud) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
WHERE addr1 IS NOT NULL
GROUP BY addr1
HAVING COUNT(DISTINCT card1) >= 3
ORDER BY distinct_cards DESC
LIMIT 20;
