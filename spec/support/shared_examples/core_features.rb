# frozen_string_literal: true

RSpec.shared_examples_for "having working core features" do |skip_examples: []|
  fab!(:category) { Fabricate(:category, name: "General") }
  fab!(:topics) { Fabricate.times(3, :topic_with_op, category:) }
  fab!(:topic)
  fab!(:active_user) { Fabricate(:active_user, password: "secure_password") }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  if skip_examples.exclude?(:login)
    describe "Login" do
      let(:login_form) { PageObjects::Pages::Login.new }

      before { EmailToken.confirm(Fabricate(:email_token, user: active_user).token) }

      it "logs in" do
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        login_form.open
        login_form.fill_username(active_user.username)
        login_form.fill_password("secure_password")
        login_form.click_login
        expect(browser_root.locator(".current-user").filter(visible: true)).not_to have_count(0)
      end

      it "displays a login button in the header" do
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(
          browser_root.locator("header .login-button").filter(visible: true),
        ).not_to have_count(0)
      end
    end
  end

  if skip_examples.exclude?(:topics)
    describe "Topics" do
      if skip_examples.exclude?(:"topics:read")
        context "with an anonymous user" do
          before { browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) } }

          it "lists latest topics" do
            expect(browser_root.locator(".topic-list-item").filter(visible: true)).to have_count(4)
          end

          it "lists topics for a category" do
            within_browser(
              browser_root.locator("#sidebar-section-content-categories").filter(visible: true),
            ) { browser_root.get_by_role("link", name: "General", exact: true).click }
            expect(browser_root.locator(".topic-list-item").filter(visible: true)).to have_count(3)
          end

          it "displays a specific topic" do
            browser_root.get_by_role("link", name: topics.first.title, exact: true).click
            expect(browser_content).to contain_text(
              browser_text_pattern(topics.first.title),
              useInnerText: true,
            )
            expect(browser_content).to contain_text(
              browser_text_pattern(topics.first.first_post.raw),
              useInnerText: true,
            )
          end
        end
      end

      context "with a logged in user" do
        before do
          sign_in(active_user)
          browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        end

        if skip_examples.exclude?(:"topics:read")
          it "lists latest topics" do
            expect(browser_root.locator(".topic-list-item").filter(visible: true)).to have_count(4)
          end

          it "lists topics for a category" do
            within_browser(
              browser_root.locator("#sidebar-section-content-categories").filter(visible: true),
            ) { browser_root.get_by_role("link", name: "General", exact: true).click }
            expect(browser_root.locator(".topic-list-item").filter(visible: true)).to have_count(3)
          end

          it "displays a specific topic" do
            browser_root.get_by_role("link", name: topics.first.title, exact: true).click
            expect(browser_content).to contain_text(
              browser_text_pattern(topics.first.title),
              useInnerText: true,
            )
            expect(browser_content).to contain_text(
              browser_text_pattern(topics.first.first_post.raw),
              useInnerText: true,
            )
          end
        end

        if skip_examples.exclude?(:"topics:reply")
          it "replies in a topic" do
            browser_root.get_by_role("link", name: topics.first.title, exact: true).click
            expect(browser_content).to contain_text(
              browser_text_pattern(topics.first.first_post.raw),
              useInnerText: true,
            )
            within_browser(browser_root.locator(".actions").filter(visible: true)) do
              browser_root
                .locator("[id=#{"Reply".to_s.to_json}], [name=#{"Reply".to_s.to_json}]")
                .or(browser_root.get_by_role("button", name: "Reply"))
                .filter(visible: true)
                .click
            end
            composer.focus
            browser_page.keyboard.type("This is a long enough reply.")
            expect(
              browser_root.locator(".d-editor-preview p").filter(visible: true),
            ).not_to have_count(0)
            within_browser(browser_root.locator(".save-or-cancel").filter(visible: true)) do
              browser_root
                .locator("[id=#{"Reply".to_s.to_json}], [name=#{"Reply".to_s.to_json}]")
                .or(browser_root.get_by_role("button", name: "Reply"))
                .filter(visible: true)
                .click
            end
            expect(browser_content).to contain_text(
              browser_text_pattern("This is a long enough reply."),
              useInnerText: true,
            )
          end
        end

        if skip_examples.exclude?(:"topics:create")
          it "creates a new topic" do
            browser_root.locator("#create-topic").filter(visible: true).click
            composer.fill_title("This is a new topic")
            composer.fill_content("This is a long enough sentence.")
            expect(
              browser_root.locator(".d-editor-preview p").filter(visible: true),
            ).not_to have_count(0)
            within_browser(browser_root.locator(".save-or-cancel").filter(visible: true)) do
              browser_root
                .locator(
                  "[id=#{"Create Topic".to_s.to_json}], [name=#{"Create Topic".to_s.to_json}]",
                )
                .or(browser_root.get_by_role("button", name: "Create Topic"))
                .filter(visible: true)
                .click
            end
            expect(browser_content).to contain_text(
              browser_text_pattern("This is a new topic"),
              useInnerText: true,
            )
            expect(browser_content).to contain_text(
              browser_text_pattern("This is a long enough sentence."),
              useInnerText: true,
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
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      it "likes a post" do
        browser_root.get_by_role("link", name: topics.first.title, exact: true).click
        topic_page.click_like_reaction_for(topics.first.posts.first)
        expect(topic_page).to have_like_count_for(topics.first.posts.first, 1)
      end
    end
  end

  if skip_examples.exclude?(:profile)
    describe "User profile" do
      fab!(:user)

      before { UserStat.update_all(post_count: 1) }

      context "with an anonymous user" do
        it "displays a user’s profile" do
          browser_page
            .goto("/u/#{user.username}/summary")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(browser_content).to contain_text(
            browser_text_pattern(user.name),
            useInnerText: true,
          )
          expect(browser_content).to contain_text(
            browser_text_pattern("Activity"),
            useInnerText: true,
          )
        end
      end

      context "with a logged in user" do
        before { sign_in(active_user) }

        it "displays a user’s profile" do
          browser_page
            .goto("/u/#{user.username}/summary")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(browser_content).to contain_text(
            browser_text_pattern(user.name),
            useInnerText: true,
          )
          expect(browser_content).to contain_text(
            browser_text_pattern("Message"),
            useInnerText: true,
          )
        end

        it "displays the user’s own profile" do
          browser_page
            .goto("/u/#{active_user.username}/summary")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(browser_content).to contain_text(
            browser_text_pattern(active_user.name),
            useInnerText: true,
          )
          expect(browser_content).to contain_text(
            browser_text_pattern("Preferences"),
            useInnerText: true,
          )
        end
      end
    end
  end

  if skip_examples.exclude?(:search)
    describe "Search" do
      let(:search_page) { PageObjects::Pages::Search.new }

      before do
        SearchIndexer.enable
        topics.each { SearchIndexer.index(it, force: true) }
        Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
      end

      after { SearchIndexer.disable }

      context "with an anonymous user" do
        if skip_examples.exclude?(:"search:quick_search")
          it "searches using the quick search" do
            browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
            search_page.click_search_icon
            search_page.type_in_search_menu(topics.first.title)
            search_page.click_search_menu_link
            expect(search_page).to have_topic_title_for_first_search_result(topics.first.title)
          end
        end

        if skip_examples.exclude?(:"search:full_page")
          it "searches using the full page search" do
            browser_page.goto("/search").tap { SystemBrowserBootstrap.wait_for(browser_page) }

            search_page.type_in_search(topics.first.title)
            search_page.click_search_button

            expect(search_page).to have_search_result
          end
        end
      end

      context "with a logged in user" do
        before { sign_in(active_user) }

        if skip_examples.exclude?(:"search:quick_search")
          it "searches using the quick search" do
            browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
            search_page.click_search_icon
            search_page.type_in_search_menu(topics.first.title)
            search_page.click_search_menu_link
            expect(search_page).to have_topic_title_for_first_search_result(topics.first.title)
          end
        end

        if skip_examples.exclude?(:"search:full_page")
          it "searches using the full page search" do
            browser_page.goto("/search").tap { SystemBrowserBootstrap.wait_for(browser_page) }

            search_page.type_in_search(topics.first.title)
            search_page.click_search_button

            expect(search_page).to have_search_result
          end
        end
      end
    end
  end

  describe "plugin javascript assets" do
    it "has expected javascript asset" do
      enabled_plugins = Discourse.plugins.filter(&:enabled?)

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_root.locator("div.discourse-root")).not_to have_count(0) # Themes might hide it

      plugin_script_tags =
        browser_root
          .locator("script[data-plugin-name], link[rel=modulepreload][data-plugin-name]")
          .all
          .map { |tag| tag.get_attribute("data-plugin-name") }

      enabled_plugins.each do |plugin|
        if plugin.js_asset_exists?
          expect(plugin_script_tags).to include(plugin.name)
        else
          expect(plugin_script_tags).not_to include(plugin.name)
        end
      end
    end
  end
end
