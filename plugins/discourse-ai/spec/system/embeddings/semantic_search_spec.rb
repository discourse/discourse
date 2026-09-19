# frozen_string_literal: true

RSpec.describe "AI semantic search in full-page search" do
  fab!(:user)
  fab!(:embedding_definition)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  let(:search_page) { PageObjects::Pages::Search.new }
  let(:query) { "apple pie" }
  let(:embedding) { [0.049382] * embedding_definition.dimensions }

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = embedding_definition.id
    SiteSetting.ai_embeddings_semantic_search_enabled = true

    DiscourseAi::Embeddings::Schema.for(Topic).store(topic, embedding, "digest")
    EmbeddingsGenerationStubs.hugging_face_service(query, embedding)

    sign_in(user)
  end

  after { DiscourseAi::Embeddings::SemanticSearch.clear_cache_for(query) }

  it "renders AI results in the toggle panel after a search" do
    visit("/search?expanded=true")
    search_page.type_in_search(query)
    search_page.click_search_button

    expect(page).to have_css(".semantic-search__results .badge-notification", text: "1")
  end
end
