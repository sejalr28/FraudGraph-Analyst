"""
Fraud ring detection using graph connectivity (analyst-friendly, no GNN training).

Idea: build a graph of card accounts (card1) as nodes. Connect two accounts with
an edge if they share a "linking" entity that legitimate independent customers
would not normally share: the same device fingerprint, the same billing address,
or the same email domain + address combo.

Connected components of size >= 3 are candidate "rings" — clusters of accounts
that are unusually linked. We rank them by fraud rate and size to prioritize
investigation.

Note on component size: capping how many accounts a single device can link
(MAX_SHARED_CARDS) stops one popular device from creating a false ring, but it
does not stop many *different* devices from chaining together transitively
(device A links accounts 1-2, device B links accounts 2-3, etc.), which can
merge into one large, low-signal "hairball" component. We cap the resulting
component size too (MAX_RING_SIZE) and report oversized components separately
instead of quietly treating a sprawling 200+ account component as one ring.

This is the same relationship logic used in the project's Neo4j graph
(see fraud_ring_queries.cypher) but runs standalone here with networkx so the
analysis works without a live Neo4j instance.

Usage:
    python graph/ring_detection.py
"""
import pandas as pd
import networkx as nx
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "data" / "fraud_sample.csv"
OUT_PATH = ROOT / "data" / "fraud_rings.csv"

MIN_SHARED_CARDS = 3   # an entity must link at least this many distinct accounts to count as a linking signal
MAX_SHARED_CARDS = 10  # cap so generic/high-volume values (e.g. "Windows", a shared zip code) aren't treated as identity links
MIN_RING_SIZE = 3      # minimum accounts in a component to call it a "ring"
MAX_RING_SIZE = 15     # components larger than this are a diffuse "hairball", not a ring -- reported separately

# Generic OS/browser strings are not a real device fingerprint (millions of legitimate
# customers share "Windows") -- only specific device builds count as a linking signal.
GENERIC_DEVICE_VALUES = {"Windows", "iOS Device", "MacOS", "Trident/7.0"}


def build_graph(df: pd.DataFrame) -> nx.Graph:
    G = nx.Graph()
    G.add_nodes_from(df["card1"].unique())

    # Only DeviceInfo is used as a linking signal here: it's the most identity-specific
    # field available (a real device fingerprint). addr1 and email domain are too coarse
    # (hundreds of legitimate customers share a billing region or "gmail.com") and would
    # produce false rings -- see README for this design decision.
    for link_col in ["DeviceInfo"]:
        sub = df.dropna(subset=[link_col])
        sub = sub[~sub[link_col].isin(GENERIC_DEVICE_VALUES)]
        sub = sub[~sub[link_col].str.match(r"^rv:\d")]  # generic Firefox version strings
        groups = sub.groupby(link_col)["card1"].unique()
        for entity, cards in groups.items():
            cards = list(set(cards))
            if not (MIN_SHARED_CARDS <= len(cards) <= MAX_SHARED_CARDS):
                continue
            # connect all pairs of accounts sharing this entity
            for i in range(len(cards)):
                for j in range(i + 1, len(cards)):
                    if G.has_edge(cards[i], cards[j]):
                        G[cards[i]][cards[j]]["shared_links"] += 1
                    else:
                        G.add_edge(cards[i], cards[j], shared_links=1)
    return G


def summarize_rings(G: nx.Graph, df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    fraud_by_card = df.groupby("card1")["isFraud"].agg(["sum", "count"])
    rows, oversized = [], []
    for i, component in enumerate(nx.connected_components(G)):
        if len(component) < MIN_RING_SIZE:
            continue
        cards = list(component)
        n_fraud = fraud_by_card.loc[fraud_by_card.index.isin(cards), "sum"].sum()
        n_txn = fraud_by_card.loc[fraud_by_card.index.isin(cards), "count"].sum()
        row = {
            "ring_id": i,
            "n_accounts": len(cards),
            "n_transactions": int(n_txn),
            "n_fraud_transactions": int(n_fraud),
            "fraud_rate_pct": round(100 * n_fraud / n_txn, 2) if n_txn else 0,
            "sample_card_ids": ", ".join(map(str, cards[:8])),
        }
        # Oversized components are a diffuse hairball (chained through many different
        # devices), not a tight-knit ring -- surface them separately rather than
        # letting one 200+ account cluster masquerade as a top "candidate ring".
        (oversized if len(cards) > MAX_RING_SIZE else rows).append(row)

    result = pd.DataFrame(rows).sort_values(["fraud_rate_pct", "n_accounts"], ascending=False)
    oversized_df = pd.DataFrame(oversized).sort_values("n_accounts", ascending=False)
    return result, oversized_df


def main():
    df = pd.read_csv(CSV_PATH)
    G = build_graph(df)
    print(f"Graph: {G.number_of_nodes():,} accounts, {G.number_of_edges():,} linking edges")

    rings, oversized = summarize_rings(G, df)
    rings.to_csv(OUT_PATH, index=False)
    print(f"Found {len(rings)} candidate rings ({MIN_RING_SIZE}-{MAX_RING_SIZE} linked accounts)")
    print(rings.to_string(index=False))

    if not oversized.empty:
        oversized_path = ROOT / "data" / "fraud_rings_oversized.csv"
        oversized.to_csv(oversized_path, index=False)
        print(f"\n{len(oversized)} oversized component(s) (> {MAX_RING_SIZE} accounts) excluded as "
              f"low-signal hairballs, saved separately for reference -> {oversized_path}")
        print(oversized.to_string(index=False))

    print(f"\nSaved -> {OUT_PATH}")


if __name__ == "__main__":
    main()
