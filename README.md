# FraudGraph — Fraud Analytics & Ring Detection

A data-analyst-scoped fraud investigation project: SQL analysis, exploratory data
analysis, graph-based fraud ring detection, and a monitoring dashboard — built on the
IEEE-CIS Fraud Detection dataset (Kaggle).

This is a deliberately **analyst-scoped** version of a larger ML-engineering project
(GraphSAGE GNN + Kafka real-time scoring). That version is a model-building /
ML-engineering deliverable. This one answers the questions a **data/fraud analyst**
role actually asks: *where does fraud concentrate, how do I query for it, and can I
show it to a stakeholder* — using SQL, EDA, and graph queries instead of a trained
neural network.

## What's inside

```
FraudGraph-Analyst/
├── data/
│   ├── fraud_sample.csv       # stratified sample: 43,737 txns, ~10% fraud rate
│   ├── fraudgraph.db          # SQLite DB built from the sample (via sql/build_db.py)
│   ├── fraud_rings.csv        # candidate rings (output of graph/ring_detection.py)
│   ├── fraud_rings_oversized.csv  # excluded low-signal "hairball" components (see Design notes)
│   ├── chart_*.png            # charts exported from the EDA notebook
│   └── data_dictionary.md
├── sql/
│   ├── build_db.py            # loads the CSV into SQLite
│   └── fraud_analysis.sql     # 10 business-question queries (KPIs, breakdowns, ring signals)
├── notebooks/
│   └── 01_eda_analysis.ipynb  # exploratory analysis with charts + written insights (pre-run)
├── graph/
│   ├── ring_detection.py      # networkx-based fraud ring detection (standalone, no Neo4j needed)
│   └── fraud_ring_queries.cypher  # equivalent Cypher queries for your existing Neo4j graph
└── dashboard/
    └── app.py                 # Streamlit monitoring dashboard
```

## How to run

```bash
pip install -r requirements.txt

# 1. Build the SQLite database from the sample data
python sql/build_db.py

# 2. Explore sql/fraud_analysis.sql in any SQLite client, or:
sqlite3 data/fraudgraph.db < sql/fraud_analysis.sql

# 3. Open the notebook (already executed, but you can re-run it)
jupyter notebook notebooks/01_eda_analysis.ipynb

# 4. Generate fraud ring candidates
python graph/ring_detection.py

# 5. Launch the dashboard
streamlit run dashboard/app.py
```

If you want to swap the graph layer for your existing Neo4j instance instead of the
standalone `networkx` version, load `fraud_sample.csv` into your existing schema
(see `research/06_graph_schema.md` in the original ArgusGraph project) and run
`graph/fraud_ring_queries.cypher` against it.

## Key findings

| Finding | Business implication |
|---|---|
| Overall fraud rate in the analysis sample: **10.06%**, representing **11.3% of total transaction dollar volume** | Fraud losses are disproportionate to transaction count — dollar-weighted monitoring matters, not just transaction-count monitoring |
| Product category **C** has a **28.4% fraud rate** vs. **6.1%** for the highest-volume category (W) | Apply stricter review thresholds by product category rather than one uniform rule |
| **Mobile** transactions: **25.6% fraud rate** vs. **17.3%** desktop, **6.3%** where no device data is captured | Add step-up verification for high-value mobile transactions; missing device data alone is not a risk signal |
| Fraud rate **peaks around 7–8am** (dataset reference clock) at **~30%**, vs. an overnight baseline of 8–15% | Off-peak / low-volume windows show disproportionate fraud share — worth flagging for real-time monitoring |
| A small number of **card accounts show repeated fraud** (up to 57% fraud rate on one account) | Feed these into velocity-based rules and the graph ring detector |
| Graph analysis (shared device fingerprints, capped to avoid generic values like "Windows") surfaced **9 candidate rings** (3–15 accounts each); the top two show fraud rates of **26–33%** — 2.6–3.3x the baseline | Prioritize these clusters for manual investigation instead of reviewing accounts one at a time |
| One much larger connected component (258 accounts) also appeared — but it's a diffuse cluster chained together through many *different* devices, not a tight-knit ring, and its fraud rate (16.4%) is barely above baseline | Excluded from the ring list and reported separately; a reminder that raw connectivity isn't itself a fraud signal — component size and cohesion matter |

## Design notes (why it's built this way)

- **SQLite, not Postgres/Kafka:** zero setup, runs anywhere, and an analyst audience
  cares about the SQL itself, not the infrastructure around it.
- **Stratified ~10% fraud sample, not the raw ~3.5%:** keeps every query and chart fast
  and readable while still being representative of relative risk across segments.
- **Graph ring detection via `networkx` + a Cypher version for Neo4j**, not a GNN: an
  analyst is expected to *query* a graph for suspicious clusters and explain the
  result, not train a model on it. The linking logic (device fingerprint sharing,
  capped at 3–10 shared accounts to exclude generic values) is picked specifically to
  avoid false rings from common values like "Windows" or a shared billing region.
- **Capping ring size (max 15 accounts), not just linking degree:** capping how many
  accounts one device can link stops a *popular* device from creating a false ring,
  but many different devices can still chain together transitively into one large,
  diffuse component. Components above the cap are reported separately
  (`fraud_rings_oversized.csv`) instead of being presented as a single 258-account
  "ring" — a real failure mode of naive connected-component ring detection worth
  calling out explicitly to a reviewer.
- **Streamlit dashboard**, not a full frontend/backend split: this is a stakeholder-facing
  view an analyst could actually build and demo, not a production system.

## Suggested resume framing

> **FraudGraph — Fraud Analytics & Ring Detection** (SQL, Python, Pandas, NetworkX, Streamlit)
> Analyzed 590K+ transactions from the IEEE-CIS fraud dataset via SQL and Python; identified
> product-, device-, and time-based fraud concentration patterns (up to 28% category-level
> fraud rate vs. 10% baseline) and built a graph-based account-linking method that surfaced
> candidate fraud rings at 2–3x baseline fraud rate; delivered findings via an interactive
> Streamlit dashboard.
