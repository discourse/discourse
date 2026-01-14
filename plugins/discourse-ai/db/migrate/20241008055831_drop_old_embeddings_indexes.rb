# frozen_string_literal: true
class DropOldEmbeddingsIndexes < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      DROP INDEX IF EXISTS ai_topic_embeddings_1_1_search;
      DROP INDEX IF EXISTS ai_topic_embeddings_2_1_search;
      DROP INDEX IF EXISTS ai_topic_embeddings_3_1_search;
      DROP INDEX IF EXISTS ai_topic_embeddings_4_1_search;
      DROP INDEX IF EXISTS ai_topic_embeddings_5_1_search;
      DROP INDEX IF EXISTS ai_topic_embeddings_6_1_search;
      DROP INDEX IF EXISTS ai_topic_embeddings_7_1_search;
      DROP INDEX IF EXISTS ai_topic_embeddings_8_1_search;

      DROP INDEX IF EXISTS ai_post_embeddings_1_1_search;
      DROP INDEX IF EXISTS ai_post_embeddings_2_1_search;
      DROP INDEX IF EXISTS ai_post_embeddings_3_1_search;
      DROP INDEX IF EXISTS ai_post_embeddings_4_1_search;
      DROP INDEX IF EXISTS ai_post_embeddings_5_1_search;
      DROP INDEX IF EXISTS ai_post_embeddings_6_1_search;
      DROP INDEX IF EXISTS ai_post_embeddings_7_1_search;
      DROP INDEX IF EXISTS ai_post_embeddings_8_1_search;

      DROP INDEX IF EXISTS ai_document_fragment_embeddings_1_1_search;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_2_1_search;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_3_1_search;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_4_1_search;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_5_1_search;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_6_1_search;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_7_1_search;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_8_1_search;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
