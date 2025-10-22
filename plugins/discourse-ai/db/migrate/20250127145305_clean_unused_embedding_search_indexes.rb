# frozen_string_literal: true
class CleanUnusedEmbeddingSearchIndexes < ActiveRecord::Migration[7.2]
  def up
    existing_definitions =
      DB.query("SELECT id, dimensions FROM embedding_definitions WHERE id <= 8")

    drop_statements =
      (1..8)
        .reduce([]) do |memo, model_id|
          model = existing_definitions.find { |ed| ed&.id == model_id }

          if model.blank? || !correctly_indexed?(model)
            embedding_tables.each do |type|
              memo << "DROP INDEX IF EXISTS ai_#{type}_embeddings_#{model_id}_1_search_bit;"
            end
          end

          memo
        end
        .join("\n")

    DB.exec(drop_statements) if drop_statements.present?

    amend_statements =
      (1..8)
        .reduce([]) do |memo, model_id|
          model = existing_definitions.find { |ed| ed&.id == model_id }

          memo << amended_idxs(model) if model.present? && !correctly_indexed?(model)

          memo
        end
        .join("\n")

    DB.exec(amend_statements) if amend_statements.present?
  end

  def embedding_tables
    %w[topics posts document_fragments]
  end

  def amended_idxs(model)
    embedding_tables.map { |t| <<~SQL }.join("\n")
      CREATE INDEX IF NOT EXISTS ai_#{t}_embeddings_#{model.id}_1_search_bit ON ai_#{t}_embeddings
      USING hnsw ((binary_quantize(embeddings)::bit(#{model.dimensions})) bit_hamming_ops)
      WHERE model_id = #{model.id} AND strategy_id = 1;
    SQL
  end

  def correctly_indexed?(edef)
    seeded_dimensions[edef.id] == edef.dimensions
  end

  def seeded_dimensions
    { 1 => 768, 2 => 1536, 3 => 1024, 4 => 1024, 5 => 768, 6 => 1536, 7 => 2000, 8 => 1024 }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
