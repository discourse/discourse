# frozen_string_literal: true

RSpec.shared_examples_for "having working core features" do |skip_examples: []|
  fab!(:category) { Fabricate(:category, name: "General") }
  fab!(:topics) { Fabricate.times(3, :topic_with_op, category:) }
  fab!(:topic)
  fab!(:active_user) { Fabricate(:active_user, password: "secure_password") }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:discovery_page) { PageObjects::Pages::Discovery.new }

  if skip_examples.exclude?(:login)
    describe "Login" do
      let(:login_form) { PageObjects::Pages::Login.new }

      before { EmailToken.confirm(Fabricate(:email_token, user: active_user).token) }

      it "logs in" do
        visit("/")

        expect(page).to have_css("header .login-button", visible: true)

        login_form.open
        login_form.fill_username(active_user.username)
        login_form.fill_password("secure_password")
        login_form.click_login

        expect(page).to have_css(".current-user", visible: true)
      end
    end
  end

  if skip_examples.exclude?(:topics)
    describe "Topics" do
      if skip_examples.exclude?(:"topics:read")
        context "with an anonymous user" do
          it "correctly allows a user to interact with topics" do
            visit "/"

            # List latest topics
            expect(page).to have_css(".topic-list-item", count: 4)

            # List topics for a category
            within("#sidebar-section-content-categories") { click_on("General") }
            expect(page).to have_css(".topic-list-item", count: 3)

            # Display a specific topic
            click_on(topics.first.title)
            expect(page).to have_content(topics.first.title)
            expect(page).to have_content(topics.first.first_post.raw)
          end
        end
      end

      context "with a logged in user" do
        before do
          sign_in(active_user)
          visit "/"
        end

        it "correctly allows a user to interact with topics" do
          if skip_examples.exclude?(:"topics:read")
            # List latest topics
            expect(page).to have_css(".topic-list-item", count: 4)

            # List topics for a category
            discovery_page.category_drop.select_row_by_name("General")
            expect(page).to have_css(".topic-list-item", count: 3)

            # Display a specific topic
            topic_list.visit_topic(topics.first)
            expect(page).to have_content(topics.first.title)
            expect(page).to have_content(topics.first.first_post.raw)
          end

          if skip_examples.exclude?(:"topics:reply")
            # Reply to a topic
            find("#site-logo", visible: true).click
            discovery_page.category_drop.select_row_by_name("General")
            expect(page).to have_css(".topic-list-item", count: 3)
            topic_list.visit_topic(topics.first)
            within(".actions") { click_button("Reply") }
            composer.focus
            send_keys("This is a long enough reply.")
            expect(page).to have_css(".d-editor-preview p", visible: true)
            within(".save-or-cancel") { click_button("Reply") }
            expect(page).to have_content("This is a long enough reply.")
          end

          if skip_examples.exclude?(:"topics:create")
            # Creates a new topic
            find("#site-logo", visible: true).click
            find("#create-topic", visible: true).click
            composer.fill_title("This is a new topic")
            composer.fill_content("This is a long enough sentence.")

            expect(page).to have_css(".d-editor-preview p", visible: true)

            within(".save-or-cancel") { click_button("Create Topic") }

            expect(topic_page).to have_title("This is a new topic")

            expect(topic_page).to have_post_content(
              post_number: 1,
              content: "This is a long enough sentence.",
            )
          end
        end
      end
    end
  end

  if skip_examples.exclude?(:likes)
    describe "Likes" do
      before do
        sign_in(active_user)
        visit "/"
      end

      it "likes a post" do
        click_on(topics.first.title)
        within(".double-button") do
          find(".toggle-like").click
          expect(page).to have_content("1")
        end
      end
    end
  end

  if skip_examples.exclude?(:profile)
    describe "User profile" do
      fab!(:user)

      before { UserStat.update_all(post_count: 1) }

      context "with an anonymous user" do
        it "displays a user’s profile" do
          visit("/u/#{user.username}/summary")
          expect(page).to have_content(user.name)
          expect(page).to have_content("Activity")
        end
      end

      context "with a logged in user" do
        it "displays user profiles correctly" do
          sign_in(active_user)

          # Another user's profile
          visit("/u/#{user.username}/summary")
          expect(page).to have_content(user.name)
          expect(page).to have_content("Message")

          # Own profile
          visit("/u/#{active_user.username}/summary")
          expect(page).to have_content(active_user.name)
          expect(page).to have_content("Preferences")
        end
      end
    end
  end

  if skip_examples.exclude?(:search)
    describe "Search" do
      let(:search_page) { PageObjects::Pages::Search.new }

      before do
        SearchIndexer.enable
        topics.each { SearchIndexer.index(_1, force: true) }
        SiteSetting.enable_welcome_banner = false
      end

      after { SearchIndexer.disable }

      context "with an anonymous user" do
        it "quick search and full page search works" do
          visit("/")

          if skip_examples.exclude?(:"search:quick_search")
            search_page.expand_dropdown
            expect(page).to have_css(".search-menu-container")
            search_page.type_in_search_menu(topics.first.title)
            search_page.click_search_menu_link
            expect(search_page).to have_topic_title_for_first_search_result(topics.first.title)
          end

          if skip_examples.exclude?(:"search:full_page")
            if advanced_search = first(".show-advanced-search")
              advanced_search.click
            else
              search_page.expand_dropdown.click_advanced_search_icon
            end

            search_page.clear_search_input.type_in_search(topics.first.title).click_search_button

            expect(search_page).to have_search_result
          end
        end
      end

      context "with a logged in user" do
        before do
          sign_in(active_user)
          visit("/")
        end

        it "quick search and full page search works" do
          if skip_examples.exclude?(:"search:quick_search")
            search_page.expand_dropdown
            expect(page).to have_css(".search-menu-container")
            search_page.type_in_search_menu(topics.first.title)
            search_page.click_search_menu_link
            expect(search_page).to have_topic_title_for_first_search_result(topics.first.title)
          end

          if skip_examples.exclude?(:"search:full_page")
            if advanced_search = first(".show-advanced-search")
              advanced_search.click
            else
              search_page.expand_dropdown.click_advanced_search_icon
            end

            search_page.clear_search_input.type_in_search(topics.first.title).click_search_button

            expect(search_page).to have_search_result
          end
        end
      end
    end
  end
end
