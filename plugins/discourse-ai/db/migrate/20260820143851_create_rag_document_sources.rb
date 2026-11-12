# frozen_string_literal: true

class CreateRagDocumentSources < ActiveRecord::Migration[8.0]
  def change
    create_table :rag_document_sources do |t|
      t.string :target_type, limit: 800, null: false
      t.bigint :target_id, null: false
      t.string :url, limit: 2000, null: false
      t.string :url_digest, limit: 64, null: false
      t.integer :refresh_interval_hours, default: 24, null: false
      t.integer :upload_id
      t.string :etag
      t.string :last_modified
      t.datetime :last_fetched_at
      t.datetime :next_refresh_at
      t.datetime :last_error_at
      t.text :last_error
      t.timestamps
    end

    add_index :rag_document_sources, %i[target_type target_id]
    add_index :rag_document_sources,
              %i[target_type target_id url_digest],
              unique: true,
              name: "idx_rag_document_sources_target_url"
    add_index :rag_document_sources, :next_refresh_at
  end
end
