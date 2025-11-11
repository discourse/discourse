# frozen_string_literal: true

class CreateOpenaiTextEmbeddingTables < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_topic_embeddings_6_1, id: false do |t|
      t.integer :topic_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1536)", null: false
      t.timestamps

      t.index :topic_id, unique: true
    end

    create_table :ai_topic_embeddings_7_1, id: false do |t|
      t.integer :topic_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(2000)", null: false
      t.timestamps

      t.index :topic_id, unique: true
    end

    create_table :ai_post_embeddings_6_1, id: false do |t|
      t.integer :post_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1536)", null: false
      t.timestamps

      t.index :post_id, unique: true
    end

    create_table :ai_post_embeddings_7_1, id: false do |t|
      t.integer :post_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(2000)", null: false
      t.timestamps

      t.index :post_id, unique: true
    end
  end
end
