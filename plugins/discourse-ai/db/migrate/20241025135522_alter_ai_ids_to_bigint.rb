# frozen_string_literal: true

class AlterAiIdsToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :ai_document_fragment_embeddings, :rag_document_fragment_id, :bigint
    change_column :classification_results, :target_id, :bigint
    change_column :rag_document_fragments, :target_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
