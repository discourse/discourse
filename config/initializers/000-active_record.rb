# frozen_string_literal: true

# No ActiveRecord for these models. Avoids the "unknown OID" warnings.
# We need it in core, because plugins are not loaded in core tests,
# but the tables are likely still present in the test database.
ActiveRecord.schema_cache_ignored_tables.push(
  "ai_topics_embeddings",
  "ai_user_embeddings",
  "ai_document_fragments_embeddings",
)
