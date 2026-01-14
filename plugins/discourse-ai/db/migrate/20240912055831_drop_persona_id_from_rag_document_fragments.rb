# frozen_string_literal: true
class DropPersonaIdFromRagDocumentFragments < ActiveRecord::Migration[7.1]
  def change
    execute <<~SQL
      UPDATE rag_document_fragments
      SET
        target_type = 'AiPersona',
        target_id = ai_persona_id
      WHERE ai_persona_id IS NOT NULL
    SQL

    # unlikely but lets be safe
    execute <<~SQL
      DELETE FROM rag_document_fragments
      WHERE target_id IS NULL OR target_type IS NULL
    SQL

    remove_column :rag_document_fragments, :ai_persona_id
    change_column_null :rag_document_fragments, :target_id, false
    change_column_null :rag_document_fragments, :target_type, false
  end
end
