# frozen_string_literal: true

describe "Search", type: :system, js: true do
  let(:search_page) { PageObjects::Pages::Search.new }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "This is a test post in a test topic") }

  describe "when using full page search on mobile" do
    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
    end

    after { SearchIndexer.disable }

    it "works and clears search page state", mobile: true do
      visit("/search")

      search_page.type_in_search("test")
      search_page.click_search_button

      expect(search_page).to have_search_result
      expect(search_page.heading_text).not_to eq("Search")

      search_page.click_home_logo
      expect(search_page.is_search_page).to be_falsey

      page.go_back
      # ensure results are still there when using browser's history
      expect(search_page).to have_search_result

      search_page.click_home_logo
      search_page.click_search_icon

      expect(search_page).not_to have_search_result
      expect(search_page.heading_text).to eq("Search")
    end
  end

  describe "when using full page search on desktop" do
    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
      SiteSetting.rate_limit_search_anon_user_per_minute = 15
      RateLimiter.enable
    end

    after { SearchIndexer.disable }

    it "rate limits searches for anonymous users" do
      queries = %w[
        one
        two
        three
        four
        five
        six
        seven
        eight
        nine
        ten
        eleven
        twelve
        thirteen
        fourteen
        fifteen
      ]

      visit("/search?expanded=true")

      queries.each do |query|
        search_page.clear_search_input
        search_page.type_in_search(query)
        search_page.click_search_button
      end

      # Rate limit error should kick in after 15 queries
      expect(search_page).to have_warning_message
    end
  end
end
