# frozen_string_literal: true

class DropOldEmbeddingsTables < ActiveRecord::Migration[7.0]
  def up
    drop_table :ai_topic_embeddings_1_1
    drop_table :ai_topic_embeddings_2_1
    drop_table :ai_topic_embeddings_3_1
    drop_table :ai_topic_embeddings_4_1
    drop_table :ai_topic_embeddings_5_1
    drop_table :ai_topic_embeddings_6_1
    drop_table :ai_topic_embeddings_7_1
    drop_table :ai_topic_embeddings_8_1
    drop_table :ai_post_embeddings_1_1
    drop_table :ai_post_embeddings_2_1
    drop_table :ai_post_embeddings_3_1
    drop_table :ai_post_embeddings_4_1
    drop_table :ai_post_embeddings_5_1
    drop_table :ai_post_embeddings_6_1
    drop_table :ai_post_embeddings_7_1
    drop_table :ai_post_embeddings_8_1
    drop_table :ai_document_fragment_embeddings_1_1
    drop_table :ai_document_fragment_embeddings_2_1
    drop_table :ai_document_fragment_embeddings_3_1
    drop_table :ai_document_fragment_embeddings_4_1
    drop_table :ai_document_fragment_embeddings_5_1
    drop_table :ai_document_fragment_embeddings_6_1
    drop_table :ai_document_fragment_embeddings_7_1
    drop_table :ai_document_fragment_embeddings_8_1
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
