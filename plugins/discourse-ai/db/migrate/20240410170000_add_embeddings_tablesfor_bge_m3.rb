# frozen_string_literal: true

class AddEmbeddingsTablesforBgeM3 < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_topic_embeddings_8_1, id: false do |t|
      t.integer :topic_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1024)", null: false
      t.timestamps

      t.index :topic_id, unique: true
    end
    create_table :ai_post_embeddings_8_1, id: false do |t|
      t.integer :post_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1024)", null: false
      t.timestamps

      t.index :post_id, unique: true
    end
    create_table :ai_document_fragment_embeddings_8_1, id: false do |t|
      t.integer :rag_document_fragment_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1024)", null: false
      t.timestamps

      t.index :rag_document_fragment_id,
              unique: true,
              name: "rag_document_fragment_id_embeddings_8_1"
    end
  end
end
