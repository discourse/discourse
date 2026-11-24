# frozen_string_literal: true
class CreateAiInferredConceptsEmbeddings < ActiveRecord::Migration[8.1]
  def up
    create_table :ai_inferred_concepts_embeddings, id: false do |t|
      t.bigint :inferred_concept_id, null: false
      t.bigint :model_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_id, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "halfvec", null: false
      t.timestamps

      t.index %i[model_id strategy_id inferred_concept_id],
              unique: true,
              name: "index_ai_concepts_embeddings_on_model_strategy_concept"
    end

    DB.query("SELECT id, dimensions FROM embedding_definitions").each { |row| execute <<~SQL }
          CREATE INDEX IF NOT EXISTS ai_inferred_concepts_embeddings_#{row.id}_1_search_bit
          ON ai_inferred_concepts_embeddings
          USING hnsw ((binary_quantize(embeddings)::bit(#{row.dimensions})) bit_hamming_ops)
          WHERE model_id = #{row.id} AND strategy_id = 1;
        SQL
  end

  def down
    drop_table :ai_inferred_concepts_embeddings
  end
end
