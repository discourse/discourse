# frozen_string_literal: true

class EmbeddingTablesForRagUploads < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_document_fragment_embeddings_1_1, id: false do |t|
      t.integer :rag_document_fragment_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(768)", null: false
      t.timestamps

      t.index :rag_document_fragment_id,
              unique: true,
              name: "rag_document_fragment_id_embeddings_1_1"
    end

    create_table :ai_document_fragment_embeddings_2_1, id: false do |t|
      t.integer :rag_document_fragment_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1536)", null: false
      t.timestamps

      t.index :rag_document_fragment_id,
              unique: true,
              name: "rag_document_fragment_id_embeddings_2_1"
    end

    create_table :ai_document_fragment_embeddings_3_1, id: false do |t|
      t.integer :rag_document_fragment_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1024)", null: false
      t.timestamps

      t.index :rag_document_fragment_id,
              unique: true,
              name: "rag_document_fragment_id_embeddings_3_1"
    end

    create_table :ai_document_fragment_embeddings_4_1, id: false do |t|
      t.integer :rag_document_fragment_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1024)", null: false
      t.timestamps

      t.index :rag_document_fragment_id,
              unique: true,
              name: "rag_document_fragment_id_embeddings_4_1"
    end

    create_table :ai_document_fragment_embeddings_5_1, id: false do |t|
      t.integer :rag_document_fragment_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(768)", null: false
      t.timestamps

      t.index :rag_document_fragment_id,
              unique: true,
              name: "rag_document_fragment_id_embeddings_5_1"
    end

    create_table :ai_document_fragment_embeddings_6_1, id: false do |t|
      t.integer :rag_document_fragment_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(1536)", null: false
      t.timestamps

      t.index :rag_document_fragment_id,
              unique: true,
              name: "rag_document_fragment_id_embeddings_6_1"
    end

    create_table :ai_document_fragment_embeddings_7_1, id: false do |t|
      t.integer :rag_document_fragment_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(2000)", null: false
      t.timestamps

      t.index :rag_document_fragment_id,
              unique: true,
              name: "rag_document_fragment_id_embeddings_7_1"
    end
  end
end
