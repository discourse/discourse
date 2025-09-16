# frozen_string_literal: true

RSpec.describe Jobs::ManageEmbeddingDefSearchIndex do
  subject(:job) { described_class.new }

  fab!(:embedding_definition)

  before { enable_current_plugin }

  describe "#execute" do
    context "when there is no embedding def" do
      it "does nothing" do
        invalid_id = 999_999_999

        job.execute(id: invalid_id)

        expect(
          DiscourseAi::Embeddings::Schema.correctly_indexed?(
            EmbeddingDefinition.new(id: invalid_id),
          ),
        ).to eq(false)
      end
    end

    context "when the embedding def is fresh" do
      it "creates the indexes" do
        job.execute(id: embedding_definition.id)

        expect(DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_definition)).to eq(true)
      end

      it "creates them only once" do
        job.execute(id: embedding_definition.id)
        job.execute(id: embedding_definition.id)

        expect(DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_definition)).to eq(true)
      end

      context "when one of the idxs is missing" do
        it "automatically recovers by creating it" do
          DB.exec <<~SQL
            CREATE INDEX IF NOT EXISTS ai_topics_embeddings_#{embedding_definition.id}_1_search_bit ON ai_topics_embeddings
            USING hnsw ((binary_quantize(embeddings)::bit(#{embedding_definition.dimensions})) bit_hamming_ops)
            WHERE model_id = #{embedding_definition.id} AND strategy_id = 1;
          SQL

          expect(DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_definition)).to eq(
            false,
          )

          job.execute(id: embedding_definition.id)

          expect(DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_definition)).to eq(
            true,
          )
        end
      end
    end
  end
end
