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
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
    end

    after { SearchIndexer.disable }

    it "handles search term cleaning and ordering for aliases" do
      # we need to be logged in for last read to show up
      sign_in(post.user)
      TopicUser.update_last_read(post.user, post.topic.id, 1, 1, 0)

      visit("/search?q=test%20r")

      expect(search_page.search_input.value).to eq("test")
      # read sort order is set to 5
      expect(search_page.sort_order.value).to eq("5")

      visit("/search?q=test%20l")

      expect(search_page.search_input.value).to eq("test")
      # latest sort order is set to 1
      expect(search_page.sort_order.value).to eq("1")
    end

    it "works and clears search page state", mobile: true do
      visit("/search")

      search_page.type_in_search("test")
      search_page.click_search_button

      expect(search_page).to have_search_result
      expect(search_page).to have_no_heading_text("Search")

      click_logo
      expect(page).to have_current_path("/")
      expect(search_page).to be_not_active

      page.go_back
      # ensure results are still there when using browser's history
      expect(search_page).to have_search_result

      click_logo
      expect(page).to have_current_path("/")

      search_page.click_search_icon

      expect(search_page).to have_no_search_result
      expect(search_page).to have_heading_text("Search")
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
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
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
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
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

    describe "with search icon in header" do
      before do
        Fabricate(:theme_site_setting_with_service, name: "search_experience", value: "search_icon")
      end

      it "displays the correct search mode" do
        visit("/")
        expect(search_page).to have_search_icon
        expect(search_page).to have_no_search_field
      end
    end

    describe "with search field in header" do
      before do
        Fabricate(
          :theme_site_setting_with_service,
          name: "search_experience",
          value: "search_field",
        )
      end

      it "displays the correct search mode" do
        visit("/")
        expect(search_page).to have_search_field
        expect(search_page).to have_no_search_icon
      end

      it "switches to search icon when header is minimized" do
        5.times { Fabricate(:post, topic: topic) }
        visit("/t/#{topic.id}")

        expect(search_page).to have_no_search_icon

        find(".timeline-date-wrapper:last-child a").click
        expect(search_page).to have_search_icon

        find(".timeline-date-wrapper:first-child a").click
        expect(search_page).to have_no_search_icon
      end

      it "does not display on login, search, signup or activate account pages" do
        visit("/login")
        expect(search_page).to have_no_search_icon
        expect(search_page).to have_no_search_field

        visit("/search")
        expect(search_page).to have_no_search_icon
        expect(search_page).to have_no_search_field

        visit("/signup")
        expect(search_page).to have_no_search_icon
        expect(search_page).to have_no_search_field

        email_token = Fabricate(:email_token, user: Fabricate(:user, active: false))
        visit("/u/activate-account/#{email_token.token}")
        expect(search_page).to have_no_search_icon
        expect(search_page).to have_no_search_field
      end

      describe "with invites" do
        fab!(:invite)

        it "does not display search field" do
          visit("/invites/#{invite.invite_key}")
          expect(search_page).to have_no_search_icon
          expect(search_page).to have_no_search_field
        end
      end

      describe "when on admin pages" do
        fab!(:admin)

        it "displays search icon regardless of Search experience setting" do
          sign_in(admin)
          visit("/admin")
          expect(search_page).to have_no_search_field
          expect(search_page).to have_search_icon
        end
      end
    end
  end

  describe "bulk actions" do
    fab!(:admin)
    fab!(:tag1, :tag)

    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
      SearchIndexer.index(topic2, force: true)
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
      sign_in(admin)
    end

    after { SearchIndexer.disable }

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

  describe "Private Message Icon in Search Results" do
    fab!(:user)
    fab!(:other_user) { Fabricate(:user) }
    fab!(:pm_topic) do
      Fabricate(
        :private_message_topic,
        user: user,
        recipient: other_user,
        title: "PM about searchable things",
      )
    end
    fab!(:pm_post) do
      Fabricate(:post, topic: pm_topic, user: user, raw: "Secret PM content searchable")
    end
    fab!(:regular_topic) { Fabricate(:topic, title: "Regular topic about searchable things") }
    fab!(:regular_post) do
      Fabricate(:post, topic: regular_topic, raw: "Regular post content searchable")
    end

    before do
      SearchIndexer.enable
      SearchIndexer.index(pm_topic, force: true)
      SearchIndexer.index(regular_topic, force: true)
      sign_in(user)
    end

    after { SearchIndexer.disable }

    it "handles different PM search filters correctly" do
      pm_filters = %w[in:messages in:personal in:personal-direct in:all-pms]

      pm_filters.each do |filter|
        visit("/search?q=searchable%20#{filter}")
        if page.has_css?(".fps-result", minimum: 1)
          expect(page).to have_css(".fps-result .topic-status .d-icon-envelope", count: 0),
          "Expected no PM icons for filter: #{filter}"
        end
      end
    end

    it "shows PM envelope icon in mixed search results with in:all filter" do
      # Search with in:all filter to get mixed results (both PM and public topics)
      visit("/search?q=searchable%20in:all")

      # The PM envelope icon should be on the PM topic specifically
      pm_result = page.find(".fps-result", text: "PM about searchable things")
      expect(pm_result).to have_css(".topic-status .d-icon-envelope")

      # The regular topic should NOT have the PM envelope icon
      regular_result = page.find(".fps-result", text: "Regular topic about searchable things")
      expect(regular_result).to have_no_css(".topic-status .d-icon-envelope")
    end
  end
end
