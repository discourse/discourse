# frozen_string_literal: true

describe "Search" do
  let(:search_page) { PageObjects::Pages::Search.new }
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic) }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "This is a test post in a test topic") }
  fab!(:topic2) { Fabricate(:topic, title: "Another test topic") }
  fab!(:post2) { Fabricate(:post, topic: topic2, raw: "This is another test post in a test topic") }

  let(:topic_bulk_actions_modal) { PageObjects::Modals::TopicBulkActions.new }
  let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

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

      browser_page.goto("/search?q=test%20r").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(search_page.search_input.input_value).to eq("test")
      # read sort order is set to 5
      expect(search_page.sort_order.value).to eq("5")

      browser_page.goto("/search?q=test%20l").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(search_page.search_input.input_value).to eq("test")
      # latest sort order is set to 1
      expect(search_page.sort_order.value).to eq("1")
    end

    it "works and clears search page state", mobile: true do
      browser_page.goto("/search").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      search_page.type_in_search("test")
      search_page.click_search_button

      expect(search_page).to have_search_result
      expect(search_page).to have_result_count

      click_logo
      expect(browser_page).to PlaywrightMatchers.have_url("/")
      expect(search_page).to be_not_active

      browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
      # ensure results are still there when using browser's history
      expect(search_page).to have_search_result

      click_logo
      expect(browser_page).to PlaywrightMatchers.have_url("/")

      search_page.click_search_icon

      expect(search_page).to have_no_search_result
      expect(search_page).to have_no_result_count
    end

    it "navigates search results using J/K keys" do
      browser_page.goto("/search").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      search_page.type_in_search("test")
      search_page.click_search_button

      expect(search_page).to have_search_result

      results =
        browser_root
          .locator(".fps-result")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all

      browser_page.keyboard.type("j")
      expect(results.first.get_attribute("class")).to include("selected")

      browser_page.keyboard.type("j")
      expect(results.last.get_attribute("class")).to include("selected")

      browser_page.keyboard.type("k")
      expect(results.first.get_attribute("class")).to include("selected")
    end
  end

  describe "when using full page search on desktop" do
    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
      SiteSetting.rate_limit_search_anon_user_per_minute = 1
      RateLimiter.enable
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
    end

    after { SearchIndexer.disable }

    it "rate limits searches for anonymous users" do
      browser_page
        .goto("/search?expanded=true")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      search_page.type_in_search("first")
      search_page.click_search_button
      expect(
        search_page.locator(".search-container .spinner").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)

      search_page.clear_search_input
      search_page.type_in_search("second")
      search_page.click_search_button

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
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
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

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      search_page.click_search_icon
      search_page.type_in_search_menu("test")
      search_page.click_search_menu_link

      expect(search_page).to have_topic_title_for_first_search_result(topic.title)
      browser_root
        .locator(".search-menu-container .search-result-topic")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern(topic.title))
        .click

      expect(SearchLog.count).to eq(1)
      expect(SearchLog.last.search_result_id).not_to eq(nil)

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
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
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
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(search_page).to have_search_field
        expect(search_page).to have_no_search_icon
      end

      it "switches to search icon when header is minimized" do
        5.times { Fabricate(:post, topic: topic) }
        browser_page.goto("/t/#{topic.id}").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(search_page).to have_no_search_icon

        browser_root.locator(".timeline-date-wrapper:last-child a").filter(visible: true).click
        expect(search_page).to have_search_icon

        browser_root.locator(".timeline-date-wrapper:first-child a").filter(visible: true).click
        expect(search_page).to have_no_search_icon
      end

      it "does not display on login, search, signup or activate account pages" do
        browser_page.goto("/login").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(search_page).to have_no_search_icon
        expect(search_page).to have_no_search_field

        browser_page.goto("/search").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(search_page).to have_no_search_icon
        expect(search_page).to have_no_search_field

        browser_page.goto("/signup").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(search_page).to have_no_search_icon
        expect(search_page).to have_no_search_field

        email_token = Fabricate(:email_token, user: Fabricate(:user, active: false))
        browser_page
          .goto("/u/activate-account/#{email_token.token}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(search_page).to have_no_search_icon
        expect(search_page).to have_no_search_field
      end

      describe "with invites" do
        fab!(:invite)

        it "does not display search field" do
          browser_page
            .goto("/invites/#{invite.invite_key}")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(search_page).to have_no_search_icon
          expect(search_page).to have_no_search_field
        end
      end

      describe "when on admin pages" do
        fab!(:admin)

        it "displays search icon regardless of Search experience setting" do
          sign_in(admin)
          browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
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
      SearchIndexer.index(post, force: true)
      SearchIndexer.index(topic2, force: true)
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
      sign_in(admin)
    end

    after { SearchIndexer.disable }

    it "allows the user to perform bulk actions on the topic search results" do
      browser_page.goto("/search?q=test").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(topic.title),
        useInnerText: true,
      )

      search_page.bulk_select_result_and_open_dropdown(topic)
      topic_list_header.click_bulk_button("manage-tags")
      manage_tags_modal = PageObjects::Modals::ManageTags.new
      manage_tags_modal.add_tags(tag1.name)
      manage_tags_modal.click_confirm
      expect(
        browser_root.locator(
          ".fps-result .fps-topic[data-topic-id=\"#{topic.id}\"] .discourse-tags",
        ).filter(visible: true),
      ).to PlaywrightMatchers.contain_text(browser_text_pattern(tag1.name), useInnerText: true)
    end

    it "allows the user to delete posts in bulk" do
      browser_page
        .goto("/search?q=This%20is%20a%20test%20post")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(post.raw),
        useInnerText: true,
      )

      search_page.bulk_select_result_and_open_dropdown(topic)
      topic_list_header.click_bulk_button("delete-posts")
      dialog.click_ok

      expect(browser_content).not_to PlaywrightMatchers.contain_text(
        browser_text_pattern(post.raw),
        useInnerText: true,
      )
      expect(Post.with_deleted.find_by(id: post.id).deleted_at).to be_present
    end

    it "lets the user bulk delete the whole topic from a reply search result" do
      browser_page
        .goto("/search?q=This%20is%20a%20test%20post")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(post.raw),
        useInnerText: true,
      )

      search_page.bulk_select_result_and_open_dropdown(topic)
      topic_list_header.click_bulk_button("delete-topics")
      topic_bulk_actions_modal.click_bulk_topics_confirm

      expect(browser_content).not_to PlaywrightMatchers.contain_text(
        browser_text_pattern(post.raw),
        useInnerText: true,
      )
      expect(topic.reload).to be_trashed
    end
  end

  describe "Private Message Icon in Search Results" do
    fab!(:user)
    fab!(:other_user, :user)
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
        browser_page
          .goto("/search?q=searchable%20#{filter}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        if PlaywrightMatchers.be_attached.matches?(
             browser_root.locator(".fps-result").filter(visible: true).nth(1 - 1),
           )
          expect(
            browser_root.locator(".fps-result .topic-status .d-icon-envelope").filter(
              visible: true,
            ),
          ).to PlaywrightMatchers.have_count(0),
          "Expected no PM icons for filter: #{filter}"
        end
      end
    end

    it "shows PM envelope icon in mixed search results with in:all filter" do
      # Search with in:all filter to get mixed results (both PM and public topics)
      browser_page
        .goto("/search?q=searchable%20in:all")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      # The PM envelope icon should be on the PM topic specifically
      pm_result =
        browser_root
          .locator(".fps-result")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("PM about searchable things"))
      expect(
        pm_result.locator(".topic-status .d-icon-envelope").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      # The regular topic should NOT have the PM envelope icon
      regular_result =
        browser_root
          .locator(".fps-result")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("Regular topic about searchable things"))
      expect(
        regular_result
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".topic-status .d-icon-envelope")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end
  end
end
