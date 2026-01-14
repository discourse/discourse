# frozen_string_literal: true

RSpec.describe "Managing Embeddings configurations", type: :system do
  fab!(:admin)
  let(:page_header) { PageObjects::Components::DPageHeader.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "correctly sets defaults" do
    preset = "text-embedding-3-small"
    api_key = "abcd"

    visit "/admin/plugins/discourse-ai/ai-embeddings"

    find(".ai-embeddings-list-editor__new-button").click()

    find("[data-preset-id='text-embedding-3-small'] button").click()

    form.field("api_key").fill_in(api_key)
    form.submit

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-embeddings")

    embedding_def = EmbeddingDefinition.order(:id).last
    expect(embedding_def.api_key).to eq(api_key)

    preset = EmbeddingDefinition.presets.find { |p| p[:preset_id] == preset }

    expect(embedding_def.display_name).to eq(preset[:display_name])
    expect(embedding_def.url).to eq(preset[:url])
    expect(embedding_def.tokenizer_class).to eq(preset[:tokenizer_class])
    expect(embedding_def.dimensions).to eq(preset[:dimensions])
    expect(embedding_def.max_sequence_length).to eq(preset[:max_sequence_length])
    expect(embedding_def.pg_function).to eq(preset[:pg_function])
    expect(embedding_def.provider).to eq(preset[:provider])
    expect(embedding_def.provider_params.symbolize_keys).to eq(preset[:provider_params])
  end

  it "supports manual config" do
    api_key = "abcd"

    visit "/admin/plugins/discourse-ai/ai-embeddings"

    find(".ai-embeddings-list-editor__new-button").click()

    find("[data-preset-id='manual'] button").click()

    form.field("display_name").fill_in("text-embedding-3-small")
    form.field("provider").select(EmbeddingDefinition::OPEN_AI)
    form.field("url").fill_in("https://api.openai.com/v1/embeddings")
    form.field("api_key").fill_in(api_key)
    form.field("tokenizer_class").select("DiscourseAi::Tokenizer::OpenAiCl100kTokenizer")

    embed_prefix = "On creation:"
    search_prefix = "On search:"
    form.field("embed_prompt").fill_in(embed_prefix)
    form.field("search_prompt").fill_in(search_prefix)
    form.field("dimensions").fill_in(1536)
    form.field("max_sequence_length").fill_in(8191)
    form.field("pg_function").select("<=>")
    form.field("provider_params.model_name").fill_in("text-embedding-3-small")

    form.submit

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-embeddings")

    embedding_def = EmbeddingDefinition.order(:id).last

    expect(embedding_def.api_key).to eq(api_key)

    preset = EmbeddingDefinition.presets.find { |p| p[:preset_id] == "text-embedding-3-small" }

    expect(embedding_def.display_name).to eq(preset[:display_name])
    expect(embedding_def.url).to eq(preset[:url])
    expect(embedding_def.tokenizer_class).to eq(preset[:tokenizer_class])
    expect(embedding_def.dimensions).to eq(preset[:dimensions])
    expect(embedding_def.max_sequence_length).to eq(preset[:max_sequence_length])
    expect(embedding_def.pg_function).to eq(preset[:pg_function])
    expect(embedding_def.provider).to eq(preset[:provider])
    expect(embedding_def.embed_prompt).to eq(embed_prefix)
    expect(embedding_def.search_prompt).to eq(search_prefix)
  end
end
