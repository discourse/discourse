# frozen_string_literal: true

class CreateBinaryIndexesForEmbeddings < ActiveRecord::Migration[7.1]
  def up
    %w[topic post document_fragment].each do |type|
      # our supported embeddings models IDs and dimensions
      [
        [1, 768],
        [2, 1536],
        [3, 1024],
        [4, 1024],
        [5, 768],
        [6, 1536],
        [7, 2000],
        [8, 1024],
      ].each { |model_id, dimensions| execute <<-SQL }
          CREATE INDEX ai_#{type}_embeddings_#{model_id}_1_search_bit ON ai_#{type}_embeddings
          USING hnsw ((binary_quantize(embeddings)::bit(#{dimensions})) bit_hamming_ops)
          WHERE model_id = #{model_id} AND strategy_id = 1;
        SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
