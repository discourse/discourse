# frozen_string_literal: true

class CreateAiPostEmbeddingsTables < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_post_embeddings_1_1, id: false do |t|
      t.integer :post_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(768)", null: false
      t.timestamps

      t.index :post_id, unique: true
    end

    create_table :ai_post_embeddings_2_1, id: false do |t|
      t.integer :post_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1536)", null: false
      t.timestamps

      t.index :post_id, unique: true
    end

    create_table :ai_post_embeddings_3_1, id: false do |t|
      t.integer :post_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1024)", null: false
      t.timestamps

      t.index :post_id, unique: true
    end

    create_table :ai_post_embeddings_4_1, id: false do |t|
      t.integer :post_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1024)", null: false
      t.timestamps

      t.index :post_id, unique: true
    end

    create_table :ai_post_embeddings_5_1, id: false do |t|
      t.integer :post_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(768)", null: false
      t.timestamps

      t.index :post_id, unique: true
    end
  end
end
