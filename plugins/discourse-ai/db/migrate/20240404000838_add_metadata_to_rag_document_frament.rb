# frozen_string_literal: true

class AddMetadataToRagDocumentFrament < ActiveRecord::Migration[7.0]
  def change
    # limit is purely for safety
    add_column :rag_document_fragments, :metadata, :text, null: true, limit: 100_000
  end
end
