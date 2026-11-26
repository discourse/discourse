# frozen_string_literal: true

describe DiscourseAi::Configuration::EmbeddingsDependencyValidator do
  subject(:validator) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)

  before { enable_current_plugin }

  it "rejects enabling inferred concepts when embeddings are disabled" do
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = false

    expect { SiteSetting.inferred_concepts_enabled = true }.to raise_error(
      Discourse::InvalidParameters,
      /enable AI embeddings/i,
    )
  end

  it "rejects enabling inferred concepts when no embedding model is selected" do
    SiteSetting.ai_embeddings_enabled = false
    SiteSetting.ai_embeddings_selected_model = ""
    SiteSetting.ai_embeddings_enabled = true

    expect { SiteSetting.inferred_concepts_enabled = true }.to raise_error(
      Discourse::InvalidParameters,
      /enable AI embeddings/i,
    )
  end

  it "allows enabling and disabling inferred concepts when embeddings are configured" do
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true

    SiteSetting.inferred_concepts_enabled = true
    expect(SiteSetting.inferred_concepts_enabled).to eq(true)

    SiteSetting.inferred_concepts_enabled = false
    expect(SiteSetting.inferred_concepts_enabled).to eq(false)
  end
end
