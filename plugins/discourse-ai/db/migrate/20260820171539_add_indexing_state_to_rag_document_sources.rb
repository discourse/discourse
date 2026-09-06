# frozen_string_literal: true

class AddIndexingStateToRagDocumentSources < ActiveRecord::Migration[8.0]
  def change
    add_column :rag_document_sources, :pending_upload_id, :integer
    add_column :rag_document_sources, :managed, :boolean, default: false, null: false
  end
end
