# frozen_string_literal: true

class CreateRagDocumentFragmentTable < ActiveRecord::Migration[7.0]
  def change
    create_table :rag_document_fragments do |t|
      t.text :fragment, null: false
      t.integer :upload_id, null: false
      t.integer :ai_persona_id, null: false
      t.integer :fragment_number, null: false
      t.timestamps
    end
  end
end
