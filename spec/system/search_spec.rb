# frozen_string_literal: true

describe "Search", type: :system do
  let(:search_page) { PageObjects::Pages::Search.new }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, raw: "This is a test post in a test topic") }
  fab!(:topic2) { Fabricate(:topic, title: "Another test topic") }
  fab!(:post2) { Fabricate(:post, topic: topic2, raw: "This is another test post in a test topic") }

  let(:topic_bulk_actions_modal) { PageObjects::Modals::TopicBulkActions.new }

  describe "when using full page search on mobile" do
    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
      SearchIndexer.index(topic2, force: true)
    end

    after { SearchIndexer.disable }

    it "works and clears search page state", mobile: true do
      visit("/search")

      search_page.type_in_search("test")
      search_page.click_search_button

      expect(search_page).to have_search_result
      expect(search_page.heading_text).not_to eq("Search")

      search_page.click_home_logo
      expect(search_page).to be_not_active

      page.go_back
      # ensure results are still there when using browser's history
      expect(search_page).to have_search_result

      search_page.click_home_logo
      search_page.click_search_icon

      expect(search_page).to have_no_search_result
      expect(search_page.heading_text).to eq("Search")
    end

    it "navigates search results using J/K keys" do
      visit("/search")

      search_page.type_in_search("test")
      search_page.click_search_button

      expect(search_page).to have_search_result

      results = all(".fps-result")

      page.send_keys("j")
      expect(results.first["class"]).to include("selected")

      page.send_keys("j")
      expect(results.last["class"]).to include("selected")

      page.send_keys("k")
      expect(results.first["class"]).to include("selected")
    end
  end

  describe "when using full page search on desktop" do
    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
      SiteSetting.rate_limit_search_anon_user_per_minute = 4
      RateLimiter.enable
    end

    after { SearchIndexer.disable }

    xit "rate limits searches for anonymous users" do
      queries = %w[one two three four]

      visit("/search?expanded=true")

      queries.each do |query|
        search_page.clear_search_input
        search_page.type_in_search(query)
        search_page.click_search_button
      end

      # Rate limit error should kick in after 4 queries
      expect(search_page).to have_warning_message
    end
  end

  describe "when search menu on desktop" do
    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
      SearchIndexer.index(topic2, force: true)
    end

    after { SearchIndexer.disable }

    it "still displays last topic search results after navigating away, then back" do
      visit("/")
      search_page.click_search_icon
      search_page.type_in_search_menu("test")
      search_page.click_search_menu_link
      expect(search_page).to have_topic_title_for_first_search_result(topic.title)

      search_page.click_first_topic
      search_page.click_search_icon
      expect(search_page).to have_topic_title_for_first_search_result(topic.title)
    end

    it "tracks search result clicks" do
      expect(SearchLog.count).to eq(0)

      visit("/")
      search_page.click_search_icon
      search_page.type_in_search_menu("test")
      search_page.click_search_menu_link

      expect(search_page).to have_topic_title_for_first_search_result(topic.title)
      find(".search-menu-container .search-result-topic", text: topic.title).click

      try_until_success { expect(SearchLog.count).to eq(1) }
      try_until_success { expect(SearchLog.last.search_result_id).not_to eq(nil) }

      log = SearchLog.last
      expect(log.term).to eq("test")
      expect(log.search_result_id).to eq(topic.first_post.id)
      expect(log.search_type).to eq(SearchLog.search_types[:header])
    end
  end

  describe "bulk actions" do
    fab!(:admin)
    fab!(:tag1) { Fabricate(:tag) }

    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
      SearchIndexer.index(topic2, force: true)
      sign_in(admin)
    end

    after { SearchIndexer.disable }

    context "when experimental_topic_bulk_actions_enabled_groups is enabled" do
      before do
        SiteSetting.experimental_topic_bulk_actions_enabled_groups =
          Group::AUTO_GROUPS[:trust_level_1]
      end

      it "allows the user to perform bulk actions on the topic search results" do
        visit("/search?q=test")
        expect(page).to have_content(topic.title)
        find(".search-info .bulk-select").click
        find(".fps-result .fps-topic[data-topic-id=\"#{topic.id}\"] .bulk-select input").click
        find(".search-info .bulk-select-topics-dropdown-trigger").click
        find(".bulk-select-topics-dropdown-content .append-tags").click
        expect(topic_bulk_actions_modal).to be_open
        tag_selector = PageObjects::Components::SelectKit.new(".tag-chooser")
        tag_selector.search(tag1.name)
        tag_selector.select_row_by_value(tag1.name)
        tag_selector.collapse
        topic_bulk_actions_modal.click_bulk_topics_confirm
        expect(
          find(".fps-result .fps-topic[data-topic-id=\"#{topic.id}\"] .discourse-tags"),
        ).to have_content(tag1.name)
      end
    end

    context "when experimental_topic_bulk_actions_enabled_groups is not enabled" do
      before { SiteSetting.experimental_topic_bulk_actions_enabled_groups = "" }

      it "allows the user to perform bulk actions on the topic search results" do
        visit("/search?q=test")
        expect(page).to have_content(topic.title)
        find(".search-info .bulk-select").click
        find(".fps-result .fps-topic[data-topic-id=\"#{topic.id}\"] .bulk-select input").click
        find(".search-info .bulk-select-btn").click
        expect(topic_bulk_actions_modal).to be_open
        find(".bulk-buttons .bulk-actions__append-tags").click
        tag_selector = PageObjects::Components::SelectKit.new(".tag-chooser")
        tag_selector.search(tag1.name)
        tag_selector.select_row_by_value(tag1.name)
        tag_selector.collapse
        find(".topic-bulk-actions__append-tags").click
        expect(
          find(".fps-result .fps-topic[data-topic-id=\"#{topic.id}\"] .discourse-tags"),
        ).to have_content(tag1.name)
      end
    end
  end
end
