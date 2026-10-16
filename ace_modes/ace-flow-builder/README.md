# ace-flow-builder - setup notes for the kb lane and the subagents

Since 0.6.0 (2026-08-28) this is one skill: the former `ace-flow-builder-kb`
flavour was merged in after two measured comparison pairs (`comparison/`).
`kb: off` in a request, or no `doc-kb` server, gives the pure local behaviour.
What the merge brought, in terms of *how context reaches the model*:

1. **Delegated generation.** Phase B3/B4 (file generation) runs in a subagent
   that reads the heavy references (`generation.md`, `msgflow_format.md`,
   `validated_rules.md`, `esql_style.md`, the matched example folder) and writes
   the project files. The main conversation only sees the generation brief and
   the returned manifest + sanity-check results. That keeps roughly 100+ KB of
   reference text out of the main context per build.
2. **doc-kb lookups.** Product-documentation questions (node property semantics,
   BIP codes, command flags) go through the `doc-kb` MCP server (`kb_search`
   against a `reference-docs` collection in Qdrant) instead of web fetches or
   bulk manual reads.

Both mechanisms degrade gracefully: no Agent tool -> the skill reads
`generation.md` inline (classic behaviour); no doc-kb server -> classic search
policy (local references, then ask the user).

## What is deliberately NOT in the vector db

Chunk retrieval is similarity-based; three document shapes break under it and
stay as deterministic file reads:

- **Validated rules / checklists** (`validated_rules.md`, the B3.7 sanity
  check): corrections for things a model gets wrong *by default*. A model that
  does not know it is about to make a mistake never issues the query that would
  retrieve the correction. These are deterministic file reads by whoever
  generates: the rules layer by its tag index (every `all` rule plus the node
  families the brief names), never a similarity query. The evidence layer
  (`validated_rules_evidence.md`: why, origin, stamp per rule) is not read
  during a build at all.
- **Process** (`workflow.md`): phase sequencing does not survive chunking.
- **Whole-artifact templates** (`.msgflow` XML, `.esql` in
  `references/examples/`): an 1800-char slice of an XML flow is useless as a
  template. They ARE in the db - but as *whole files behind a searchable
  description* (see "Examples index" below), never as chunks.

## Setup (kb path)

Without any of this the skill still works in classic mode. For the kb path you
need an MCP server named `doc-kb` exposing `kb_search(query, collection, top_k)`
and `kb_collections()`, backed by a vector store holding a `reference-docs`
collection with your product documentation.

Reference implementation (what this skill was developed against):

- Qdrant in Docker (`localhost:6333`), one named vector `dense`
  (`BAAI/bge-base-en-v1.5`, 768-dim, cosine) + one sparse vector `bm25`
  (`Qdrant/bm25`, IDF modifier), queried with RRF fusion of the two.
- Ingestion: convert docs to a markdown mirror (Docling), heading-aware
  chunking (~1800 chars, 200 overlap), embed dense + sparse, upsert with
  content-hash point ids; incremental via per-file hashes.
- MCP server: a thin Python stdio server wrapping the hybrid query, registered
  with `claude mcp add doc-kb -- <python> <server.py>`.

You must ingest **your own** documentation export. The IBM ACE/MQ manuals are
licensed material and are not shipped with this skill; an offline infocenter
export (PDF) of the version you run is the right source.

## Examples index: the `ace-flow-kb` collection

The 94 pattern folders under `references/examples/` are ingested as
whole-artifact records - ONE point per pattern, never chunks. The embedded text
is a synthesized description (pattern name, protocol/format synonyms, node
types extracted from the `.msgflow`, ESQL module names); the payload carries
the full file contents plus the folder path. Phase B0 pattern matching is then
one `kb_search(collection="ace-flow-kb")` instead of reading the catalog, and
the corpus can grow (own flows, customer house patterns) without touching the
skill.

Build or rebuild it (any python with `qdrant-client` + `fastembed`; run from
the skill folder):

```
python setup/ingest_examples.py
```

Semantics worth knowing:

- **Rebuild-on-run.** The collection is dropped and recreated every run - it is
  a derived index of ~100 small points; the rebuild IS the deletion design.
  Re-run after adding, changing, or removing example folders.
- **Direction is a near-tie.** `DatabasetoKafka` and `KafkatoDatabase` have
  identical BM25 token bags, so the pair ranks together and order between them
  is arbitrary. The skill picks the direction from the record's
  `Direction: input from X, output to Y` line, never from rank. Any A-to-B
  corpus has this property - resolve direction at the consumer, not in the
  retrieval layer.
- The self-check at the end of every run asserts three known queries each
  return their pattern in the top 3, and fails the run otherwise.

## Comparing kb on vs kb off

Since the merge the comparison is a single-variable experiment: the same skill
with `kb: off` in the prompt versus without. Protocol, prompts, answer sheets,
per-run results and the expert-review blocks live in
[comparison/PROTOCOL.md](comparison/PROTOCOL.md). Pick a flow whose facts live
only in the manual (a Kafka SASL policy, a JMS provider configuration) -
another HTTP/MQ variant measures nothing, because the references already hold
those facts. One Level-3 build per quota window.

Run the same build prompt through both skills (name them explicitly to pin the
flavour). Compare:

- token usage of the turn (the main-context saving is the point; subagent
  tokens still cost, but they do not accumulate in the conversation),
- wall time to first artifact,
- artifact quality: B3.7 sanity check results, then an `ace-review-quick` pass
  on both outputs.

Findings that show a quality gap go back into `generation.md` or the subagent
prompt in SKILL.md Phase B3 - not into loosening the comparison.
