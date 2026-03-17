# frozen_string_literal: true
class DropOldEmbeddingTables2 < ActiveRecord::Migration[7.2]
  def up
    if table_exists?(:ai_document_fragment_embeddings)
      # Copy rag embeddings created during deploy.
      execute <<~SQL
          INSERT INTO ai_document_fragments_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
          (
            SELECT  old_table.*
            FROM ai_document_fragment_embeddings old_table
            LEFT OUTER JOIN ai_document_fragments_embeddings target ON (
              target.model_id = old_table.model_id AND
              target.strategy_id = old_table.strategy_id AND
              target.rag_document_fragment_id = old_table.rag_document_fragment_id
            )
            WHERE target.rag_document_fragment_id IS NULL
          )
        SQL
    end

    execute <<~SQL
        DROP INDEX IF EXISTS ai_topic_embeddings_1_1_search_bit;
        DROP INDEX IF EXISTS ai_topic_embeddings_2_1_search_bit;
        DROP INDEX IF EXISTS ai_topic_embeddings_3_1_search_bit;
        DROP INDEX IF EXISTS ai_topic_embeddings_4_1_search_bit;
        DROP INDEX IF EXISTS ai_topic_embeddings_5_1_search_bit;
        DROP INDEX IF EXISTS ai_topic_embeddings_6_1_search_bit;
        DROP INDEX IF EXISTS ai_topic_embeddings_7_1_search_bit;
        DROP INDEX IF EXISTS ai_topic_embeddings_8_1_search_bit;
        DROP INDEX IF EXISTS ai_post_embeddings_1_1_search_bit;
        DROP INDEX IF EXISTS ai_post_embeddings_2_1_search_bit;
        DROP INDEX IF EXISTS ai_post_embeddings_3_1_search_bit;
        DROP INDEX IF EXISTS ai_post_embeddings_4_1_search_bit;
        DROP INDEX IF EXISTS ai_post_embeddings_5_1_search_bit;
        DROP INDEX IF EXISTS ai_post_embeddings_6_1_search_bit;
        DROP INDEX IF EXISTS ai_post_embeddings_7_1_search_bit;
        DROP INDEX IF EXISTS ai_post_embeddings_8_1_search_bit;
        DROP INDEX IF EXISTS ai_document_fragment_embeddings_1_1_search_bit;
        DROP INDEX IF EXISTS ai_document_fragment_embeddings_2_1_search_bit;
        DROP INDEX IF EXISTS ai_document_fragment_embeddings_3_1_search_bit;
        DROP INDEX IF EXISTS ai_document_fragment_embeddings_4_1_search_bit;
        DROP INDEX IF EXISTS ai_document_fragment_embeddings_5_1_search_bit;
        DROP INDEX IF EXISTS ai_document_fragment_embeddings_6_1_search_bit;
        DROP INDEX IF EXISTS ai_document_fragment_embeddings_7_1_search_bit;
        DROP INDEX IF EXISTS ai_document_fragment_embeddings_8_1_search_bit;
      SQL

    drop_table :ai_topic_embeddings, if_exists: true
    drop_table :ai_post_embeddings, if_exists: true
    drop_table :ai_document_fragment_embeddings, if_exists: true
  end

  def down
  end
end
