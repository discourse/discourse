# frozen_string_literal: true
class BackfillRagEmbeddings < ActiveRecord::Migration[7.2]
  def up
    if table_exists?(:ai_document_fragment_embeddings)
      not_backfilled =
        DB.query_single("SELECT COUNT(*) FROM ai_document_fragments_embeddings").first.to_i == 0

      if not_backfilled
        # Copy data from old tables to new tables
        execute <<~SQL
          INSERT INTO ai_document_fragments_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
          SELECT * FROM ai_document_fragment_embeddings;
        SQL
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
