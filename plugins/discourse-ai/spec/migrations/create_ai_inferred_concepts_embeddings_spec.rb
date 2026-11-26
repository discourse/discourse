# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20261124152608_create_ai_inferred_concepts_embeddings.rb",
        )

RSpec.describe CreateAiInferredConceptsEmbeddings do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "creates ai_inferred_concepts_embeddings and HNSW indexes for existing embedding definitions" do
    definition = Fabricate(:embedding_definition)

    described_class.new.down
    described_class.new.up

    index_name =
      DiscourseAi::Embeddings::Schema.search_index_name("inferred_concepts", definition.id)
    index_defs =
      DB.query_single(
        "SELECT indexdef FROM pg_indexes WHERE tablename = 'ai_inferred_concepts_embeddings' AND indexname = :name",
        name: index_name,
      )

    expect(index_defs.length).to eq(1)
    expect(index_defs.first).to include(
      "(binary_quantize(embeddings))::bit(#{definition.dimensions})",
    )
  end
end
