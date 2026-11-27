# frozen_string_literal: true

describe "Search selected post text" do
  fab!(:user)
  fab!(:post) { Fabricate(:post, raw: "The phrase A & B appears in this post.") }

  it "keeps the search action hidden by default" do
    sign_in(user)
    visit post.topic.relative_url
    select_text_range(".cooked p", 11, 5)

    expect(page).to have_css(".quote-button")
    expect(page).to have_no_css(".search-post-selection")
  end

  it "opens forum search with the exact selected text in the query parameter" do
    SiteSetting.show_post_selection_search = true
    sign_in(user)
    visit post.topic.relative_url
    select_text_range(".cooked p", 11, 5)

    find(".search-post-selection").click

    expect(page).to have_current_path(%r{/search\?})
    expect(URI.decode_www_form(URI.parse(page.current_url).query).to_h["q"]).to eq("A & B")
  end

  it "keeps the search action hidden when anonymous search is disabled" do
    SiteSetting.show_post_selection_search = true
    SiteSetting.allow_anonymous_search = false
    visit post.topic.relative_url
    select_text_range(".cooked p", 11, 5)

    expect(page).to have_css(".quote-button")
    expect(page).to have_no_css(".search-post-selection")
  end
end
