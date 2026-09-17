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

  it "shows no user results after switching from related post results" do
    visit("/search?expanded=true")
    search_page.type_in_search(query)
    search_page.click_search_button
    expect(search_page).to have_related_results
    expect(search_page).to have_result_count

    search_page.switch_to_users
    expect(page).to have_current_path("/search?expanded=true&q=apple%20pie&search_type=users")
    expect(search_page).to have_no_user_results
    expect(search_page).to have_full_page_no_results
    expect(search_page).to have_no_result_count

    page.refresh
    expect(search_page).to have_full_page_no_results
    expect(search_page).to have_no_result_count
  end

  it "counts only matching users after switching from related post results" do
    matching_users = [
      Fabricate(:user, username: "apple_pie_one", name: "Apple Pie"),
      Fabricate(:user, username: "apple_pie_two", name: "Apple Pie"),
    ]
    SearchIndexer.with_indexing do
      matching_users.each { |matching_user| SearchIndexer.index(matching_user, force: true) }
    end

    visit("/search?expanded=true")
    search_page.type_in_search(query)
    search_page.click_search_button
    expect(search_page).to have_related_results

    search_page.switch_to_users
    expect(search_page).to have_user_results(count: 2)
    expect(search_page).to have_result_count_for(count: 2, term: query)
  end

  it "renders AI results in the toggle panel after a search" do
    visit("/search?expanded=true")
    search_page.type_in_search(query)
    search_page.click_search_button

    expect(page).to have_css(".semantic-search__results .badge-notification", text: "1")
  end
end
