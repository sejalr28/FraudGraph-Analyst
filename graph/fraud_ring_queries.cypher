// FraudGraph Analyst — Neo4j Cypher queries
// Use these against the graph you already built in Neo4j (nodes: User/Card, Device,
// Merchant, etc. per your existing schema in research/06_graph_schema.md).
// They mirror the same ring-detection logic as graph/ring_detection.py, but as
// analyst-friendly Cypher instead of a trained GNN -- the point for this scope of
// project is "can you write graph queries that surface fraud rings", not "can you
// train a graph neural network".

// ---------------------------------------------------------
// 1. Devices shared by multiple distinct card accounts
//    (a device fingerprint used by several "different" payers is a classic ring signal)
// ---------------------------------------------------------
MATCH (c:Card)-[:USED_DEVICE]->(d:Device)
WITH d, collect(DISTINCT c.card1) AS cards
WHERE size(cards) >= 3 AND size(cards) <= 10
RETURN d.deviceInfo AS device, size(cards) AS distinct_cards, cards
ORDER BY distinct_cards DESC
LIMIT 20;

// ---------------------------------------------------------
// 2. Candidate fraud rings: connected components of cards linked via shared devices
//    Requires the Graph Data Science (GDS) library, which ships with Neo4j Desktop.
// ---------------------------------------------------------
CALL gds.graph.project(
    'cardDeviceGraph',
    ['Card', 'Device'],
    { USED_DEVICE: { orientation: 'UNDIRECTED' } }
);

CALL gds.wcc.stream('cardDeviceGraph')
YIELD nodeId, componentId
WITH componentId, gds.util.asNode(nodeId) AS n
WHERE n:Card
WITH componentId, collect(n.card1) AS cards
// Cap ring size as well as per-device linking degree: many different devices can
// still chain accounts together transitively into one large, low-signal component.
// See graph/ring_detection.py for the same cap (MAX_RING_SIZE) and rationale.
WHERE size(cards) >= 3 AND size(cards) <= 15
RETURN componentId, size(cards) AS ring_size, cards
ORDER BY ring_size DESC
LIMIT 20;

// ---------------------------------------------------------
// 3. Fraud rate inside each candidate ring (join back to transactions)
// ---------------------------------------------------------
MATCH (c:Card)-[:MADE]->(t:Transaction)
WHERE c.card1 IN $ring_card_ids   // pass in the card list from query 2
RETURN
    count(t)                              AS n_transactions,
    sum(CASE WHEN t.isFraud = 1 THEN 1 ELSE 0 END) AS n_fraud,
    round(100.0 * sum(CASE WHEN t.isFraud = 1 THEN 1 ELSE 0 END) / count(t), 2) AS fraud_rate_pct;

// ---------------------------------------------------------
// 4. Shortest path between two flagged accounts (investigation drill-down)
//    Useful for an analyst building a case file: "how are these two accounts connected?"
// ---------------------------------------------------------
MATCH path = shortestPath(
    (c1:Card {card1: $card_id_1})-[*..6]-(c2:Card {card1: $card_id_2})
)
RETURN path;

// ---------------------------------------------------------
// 5. Merchant-level exposure: which merchants see the most flagged rings
// ---------------------------------------------------------
MATCH (c:Card)-[:MADE]->(t:Transaction)-[:AT]->(m:Merchant)
WHERE c.card1 IN $ring_card_ids
RETURN m.name AS merchant, count(t) AS n_transactions,
       sum(CASE WHEN t.isFraud = 1 THEN 1 ELSE 0 END) AS n_fraud
ORDER BY n_fraud DESC
LIMIT 10;
