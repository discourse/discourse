# frozen_string_literal: true

class AddTargetToRagDocumentFragment < ActiveRecord::Migration[7.1]
  def change
    add_column :rag_document_fragments, :target_id, :integer, null: true
    add_column :rag_document_fragments, :target_type, :string, limit: 800, null: true
    add_index :rag_document_fragments, %i[target_type target_id]
  end
end
