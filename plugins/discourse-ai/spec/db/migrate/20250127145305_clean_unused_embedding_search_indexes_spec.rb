# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20250127145305_clean_unused_embedding_search_indexes",
        )

RSpec.describe CleanUnusedEmbeddingSearchIndexes do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  before { enable_current_plugin }

  describe "#up" do
    before do
      # Copied from 20241008054440_create_binary_indexes_for_embeddings
      %w[topics posts document_fragments].each do |type|
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
        ].each { |model_id, dimensions| connection.execute <<-SQL }
          CREATE INDEX IF NOT EXISTS ai_#{type}_embeddings_#{model_id}_1_search_bit ON ai_#{type}_embeddings
          USING hnsw ((binary_quantize(embeddings)::bit(#{dimensions})) bit_hamming_ops)
          WHERE model_id = #{model_id} AND strategy_id = 1;
        SQL
      end
    end

    let(:all_idx_names) do
      %w[topics posts document_fragments].reduce([]) do |memo, type|
        (1..8).each { |model_id| memo << "ai_#{type}_embeddings_#{model_id}_1_search_bit" }

        memo
      end
    end

    context "when there are no embedding definitions" do
      it "removes all indexes" do
        migration.up

        remaining_idxs =
          DB.query_single(
            "SELECT indexname FROM pg_indexes WHERE indexname IN (:names)",
            names: all_idx_names,
          )

        expect(remaining_idxs).to be_empty
      end
    end

    context "when there is an embedding definition with the same dimensions" do
      fab!(:embedding_def) { Fabricate(:embedding_definition, id: 2, dimensions: 1536) }

      it "keeps the matching index and removes the rest" do
        expected_model_idxs =
          %w[topics posts document_fragments].reduce([]) do |memo, type|
            memo << "ai_#{type}_embeddings_2_1_search_bit"
          end

        migration.up

        remaining_idxs =
          DB.query_single(
            "SELECT indexname FROM pg_indexes WHERE indexname IN (:names)",
            names: all_idx_names,
          )

        expect(remaining_idxs).to contain_exactly(*expected_model_idxs)
        # This method checks dimensions are correct.
        expect(DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_def)).to eq(true)
      end
    end

    context "when there is an embedding definition with different dimensions" do
      fab!(:embedding_def) { Fabricate(:embedding_definition, id: 2, dimensions: 1536) }
      fab!(:embedding_def_2) { Fabricate(:embedding_definition, id: 3, dimensions: 768) }

      it "updates the index to use the right dimensions" do
        expected_model_idxs =
          %w[topics posts document_fragments].reduce([]) do |memo, type|
            memo << "ai_#{type}_embeddings_2_1_search_bit"
            memo << "ai_#{type}_embeddings_3_1_search_bit"
          end

        migration.up

        remaining_idxs =
          DB.query_single(
            "SELECT indexname FROM pg_indexes WHERE indexname IN (:names)",
            names: all_idx_names,
          )

        expect(remaining_idxs).to contain_exactly(*expected_model_idxs)
        # This method checks dimensions are correct.
        expect(DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_def_2)).to eq(true)
      end
    end

    context "when there are indexes outside the pre-seeded range" do
      before { %w[topics posts document_fragments].each { |type| connection.execute <<-SQL } }
            CREATE INDEX IF NOT EXISTS ai_#{type}_embeddings_9_1_search_bit ON ai_#{type}_embeddings
            USING hnsw ((binary_quantize(embeddings)::bit(556)) bit_hamming_ops)
            WHERE model_id = 9 AND strategy_id = 1;
          SQL

      let(:all_idx_names) do
        %w[topics posts document_fragments].reduce([]) do |memo, type|
          (1..8).each { |model_id| memo << "ai_#{type}_embeddings_#{model_id}_1_search_bit" }

          memo
        end
      end

      it "leaves them untouched" do
        expected_model_idxs =
          %w[topics posts document_fragments].reduce([]) do |memo, type|
            memo << "ai_#{type}_embeddings_9_1_search_bit"
          end

        migration.up

        other_idxs =
          DB.query_single(
            "SELECT indexname FROM pg_indexes WHERE indexname IN (:names)",
            names: expected_model_idxs,
          )

        expect(other_idxs).to contain_exactly(*expected_model_idxs)
      end
    end
  end
end
