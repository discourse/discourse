# frozen_string_literal: true

class MoveEmbeddingsToSingleTablePerType < ActiveRecord::Migration[7.0]
  def up
    create_table :ai_topic_embeddings, id: false do |t|
      t.integer :topic_id, null: false
      t.integer :model_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_id, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "halfvec", null: false
      t.timestamps

      t.index %i[model_id strategy_id topic_id],
              unique: true,
              name: "index_ai_topic_embeddings_on_model_strategy_topic"
    end

    create_table :ai_post_embeddings, id: false do |t|
      t.integer :post_id, null: false
      t.integer :model_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_id, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "halfvec", null: false
      t.timestamps

      t.index %i[model_id strategy_id post_id],
              unique: true,
              name: "index_ai_post_embeddings_on_model_strategy_post"
    end

    create_table :ai_document_fragment_embeddings, id: false do |t|
      t.integer :rag_document_fragment_id, null: false
      t.integer :model_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_id, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "halfvec", null: false
      t.timestamps

      t.index %i[model_id strategy_id rag_document_fragment_id],
              unique: true,
              name: "index_ai_fragment_embeddings_on_model_strategy_fragment"
    end

    # Copy data from old tables to new tables
    execute <<-SQL
      INSERT INTO ai_topic_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT topic_id, 1, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_topic_embeddings_1_1;

      INSERT INTO ai_topic_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT topic_id, 2, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_topic_embeddings_2_1;

      INSERT INTO ai_topic_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT topic_id, 3, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_topic_embeddings_3_1;

      INSERT INTO ai_topic_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT topic_id, 4, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_topic_embeddings_4_1;

      INSERT INTO ai_topic_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT topic_id, 5, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_topic_embeddings_5_1;

      INSERT INTO ai_topic_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT topic_id, 6, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_topic_embeddings_6_1;

      INSERT INTO ai_topic_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT topic_id, 7, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_topic_embeddings_7_1;

      INSERT INTO ai_topic_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT topic_id, 8, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_topic_embeddings_8_1;

      INSERT INTO ai_post_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT post_id, 1, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_post_embeddings_1_1;

      INSERT INTO ai_post_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT post_id, 2, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_post_embeddings_2_1;

      INSERT INTO ai_post_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT post_id, 3, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_post_embeddings_3_1;

      INSERT INTO ai_post_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT post_id, 4, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_post_embeddings_4_1;

      INSERT INTO ai_post_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT post_id, 5, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_post_embeddings_5_1;

      INSERT INTO ai_post_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT post_id, 6, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_post_embeddings_6_1;

      INSERT INTO ai_post_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT post_id, 7, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_post_embeddings_7_1;

      INSERT INTO ai_post_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT post_id, 8, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_post_embeddings_8_1;

      INSERT INTO ai_document_fragment_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT rag_document_fragment_id, 1, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_document_fragment_embeddings_1_1;

      INSERT INTO ai_document_fragment_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT rag_document_fragment_id, 2, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_document_fragment_embeddings_2_1;

      INSERT INTO ai_document_fragment_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT rag_document_fragment_id, 3, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_document_fragment_embeddings_3_1;

      INSERT INTO ai_document_fragment_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT rag_document_fragment_id, 4, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_document_fragment_embeddings_4_1;

      INSERT INTO ai_document_fragment_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT rag_document_fragment_id, 5, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_document_fragment_embeddings_5_1;

      INSERT INTO ai_document_fragment_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT rag_document_fragment_id, 6, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_document_fragment_embeddings_6_1;

      INSERT INTO ai_document_fragment_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT rag_document_fragment_id, 7, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_document_fragment_embeddings_7_1;

      INSERT INTO ai_document_fragment_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT rag_document_fragment_id, 8, model_version, 1, strategy_version, digest, embeddings, created_at, updated_at
      FROM ai_document_fragment_embeddings_8_1;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
