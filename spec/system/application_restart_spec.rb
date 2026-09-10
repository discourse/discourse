# frozen_string_literal: true
RSpec.describe "Application restart" do
  fab!(:user)
  fab!(:other_user, :user)

  before do
    unless ENV["SYSTEM_TEST_REUSE_APPLICATION"] == "1"
      skip "Requires SYSTEM_TEST_REUSE_APPLICATION=1"
    end
  end

  def observe_browser(&block)
    Capybara::Playwright::DriverExtension.instance_method(:with_playwright_page).bind_call(
      page.driver,
      &block
    )
  end

  describe "#visit" do
    it "loads fresh server state with a new application owner" do
      visit "/latest"
      observe_browser do |observed_page|
        previous_owner = observed_page.evaluate_handle("() => window.Discourse")
        topic = Fabricate(:topic, title: "Fresh server topic")

        visit "/latest"

        expect(page).to have_link(topic.title)
        expect(
          previous_owner.evaluate("(owner) => owner.isDestroyed && owner !== window.Discourse"),
        ).to eq(true)
        expect(page.driver.status_code).to eq(200)
      end
    end

    it "continues an incompatible document once and runs its new inline script" do
      visit "/latest"
      SiteSetting.title = "Changed document title"
      builder =
        proc do |controller|
          %(<script nonce="#{controller.helpers.csp_nonce_placeholder}">window.applicationRestartNewDocument = true;</script>)
        end
      DiscoursePluginRegistry.register_html_builder("server:before-head-close", &builder)
      requests = []
      listener =
        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
          requests << payload if payload[:path] == "/latest"
        end

      visit "/latest"

      expect(requests.length).to eq(1)
      expect(page).to have_title("Changed document title")
      expect(page.evaluate_script("window.applicationRestartNewDocument")).to eq(true)
      expect(page.driver.status_code).to eq(200)
    ensure
      ActiveSupport::Notifications.unsubscribe(listener) if listener
      DiscoursePluginRegistry.html_builders["server:before-head-close"]&.delete(builder)
    end

    it "loads a real document for a fragment after resetting the owner" do
      visit "/latest"
      observe_browser do |observed_page|
        previous_owner = observed_page.evaluate_handle("() => window.Discourse")
        Capybara.reset_sessions!
        expect(page.driver).to be_application_restart_pending

        visit "/latest#restart-anchor"

        expect(page).to have_current_path("/latest")
        expect { previous_owner.evaluate("(owner) => owner.isDestroyed") }.to raise_error(
          Playwright::Error,
          /Execution context was destroyed/,
        )
        expect(
          observed_page.evaluate("() => !!window.Discourse && !window.Discourse.isDestroying"),
        ).to eq(true)
      end
    end

    it "keeps direct authentication documents native" do
      visit "/latest"

      visit "/session/#{user.encoded_username}/become.json?redirect=false"

      expect(page).to have_content("Signed in to #{user.encoded_username} successfully")
      expect(page).to have_current_path(
        "/session/#{user.encoded_username}/become.json?redirect=false",
      )
    end
  end

  describe "#refresh" do
    it "reloads server state while preserving the session" do
      listener = nil
      sign_in(user)
      visit "/latest"
      observe_browser do |observed_page|
        previous_owner = observed_page.evaluate_handle("() => window.Discourse")
        topic = Fabricate(:topic, title: "Refreshed server topic")

        requests = []
        listener =
          ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
            requests << payload if payload[:path] == "/latest"
          end

        page.refresh

        expect(requests.length).to eq(1)
        expect(page).to have_link(topic.title)
        expect(page).to have_current_path("/latest")
        expect { previous_owner.evaluate("(owner) => owner.isDestroyed") }.to raise_error(
          Playwright::Error,
          /Execution context was destroyed/,
        )
        expect(
          observed_page.evaluate("() => window.Discourse.lookup('service:current-user').username"),
        ).to eq(user.username)
      end
    ensure
      ActiveSupport::Notifications.unsubscribe(listener) if listener
    end
  end

  describe "#reset!" do
    it "keeps shared search tips until their final owner is destroyed" do
      Fabricate(:theme_site_setting_with_service, name: "search_experience", value: "search_icon")
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
      visit "/latest"
      observe_browser { |observed_page| observed_page.evaluate(<<~JAVASCRIPT) }
          () => {
            window.applicationRestartTipTest = { random: Math.random, first: {}, second: {}, replacement: {} };
            Math.random = () => 0.999999;
          }
        JAVASCRIPT
      page.find("#search-button").click
      default_tip = page.find(".search-random-quick-tip .tip-label").text
      page.find("#search-button").click
      observe_browser { |observed_page| observed_page.evaluate(<<~JAVASCRIPT) }
          () => {
            const state = window.applicationRestartTipTest;
            state.tip = { label: 'Shared test tip', description: 'First description' };
            const { addQuickSearchRandomTip } = require('discourse/components/search-menu/results/random-quick-tip');
            addQuickSearchRandomTip(state.tip, { owner: state.first });
            addQuickSearchRandomTip(state.tip, { owner: state.second });
            require('@ember/runloop').run(() => require('@ember/destroyable').destroy(state.first));
            state.tip.description = 'Updated description';
          }
        JAVASCRIPT

      page.find("#search-button").click

      expect(page).to have_css(".search-random-quick-tip", text: "Updated description")
      page.find("#search-button").click
      observe_browser { |observed_page| observed_page.evaluate(<<~JAVASCRIPT) }
          () => {
            const state = window.applicationRestartTipTest;
            require('@ember/runloop').run(() => require('@ember/destroyable').destroy(state.second));
          }
        JAVASCRIPT
      page.find("#search-button").click
      expect(page).to have_css(".search-random-quick-tip .tip-label", exact_text: default_tip)
      page.find("#search-button").click
      observe_browser { |observed_page| observed_page.evaluate(<<~JAVASCRIPT) }
          () => {
            const state = window.applicationRestartTipTest;
            const registry = require('discourse/components/search-menu/results/random-quick-tip');
            state.beforeReset = {};
            registry.addQuickSearchRandomTip(state.tip, { owner: state.beforeReset });
            registry.resetQuickSearchRandomTips();
            registry.addQuickSearchRandomTip(state.tip, { owner: state.replacement });
            require('@ember/runloop').run(() => require('@ember/destroyable').destroy(state.beforeReset));
          }
        JAVASCRIPT
      page.find("#search-button").click
      expect(page).to have_css(".search-random-quick-tip", text: "Updated description")
    ensure
      observe_browser { |observed_page| observed_page.evaluate(<<~JAVASCRIPT) }
          () => {
            const state = window.applicationRestartTipTest;
            if (!state) return;
            require('@ember/runloop').run(() => {
              for (const owner of [state.first, state.second, state.beforeReset, state.replacement]) {
                if (owner) require('@ember/destroyable').destroy(owner);
              }
            });
            Math.random = state.random;
            delete window.applicationRestartTipTest;
          }
        JAVASCRIPT
    end

    it "clears fixture authentication before another application boot" do
      visit "/latest"
      Capybara.reset_sessions!
      sign_in(user)

      Capybara.reset_sessions!
      visit "/latest"

      expect(page).to have_css(".login-button")
      observe_browser do |observed_page|
        expect(
          observed_page.evaluate("() => window.Discourse.lookup('service:current-user') === null"),
        ).to eq(true)
      end
    end

    it "clears cookies, storage, history and viewport before the next boot" do
      sign_in(user)
      visit "/latest"
      observe_browser { |observed_page| observed_page.evaluate(<<~JAVASCRIPT) }
          () => {
        localStorage.setItem('restart-isolation', 'first');
        sessionStorage.setItem('restart-isolation', 'first');
        document.cookie = 'restart-isolation=first; path=/';
        history.pushState(null, '', '/?previous-example=1');
        history.pushState(null, '', '/latest');
          }
        JAVASCRIPT
      page.current_window.resize_to(900, 700)

      Capybara.reset_sessions!
      expect(page.driver).to be_application_restart_pending
      visit "/latest"

      expect(page.evaluate_script("localStorage.getItem('restart-isolation') === null")).to eq(true)
      expect(page.evaluate_script("sessionStorage.getItem('restart-isolation') === null")).to eq(
        true,
      )
      expect(page.evaluate_script("document.cookie")).not_to include("restart-isolation")
      expect(
        page.evaluate_script("window.Discourse.lookup('service:current-user') === null"),
      ).to eq(true)
      expect(page.current_window.size).to eq([1400, 1400])
      history_urls =
        observe_browser do |browser_page|
          session = browser_page.context.new_cdp_session(browser_page)
          begin
            session
              .send_message("Page.getNavigationHistory")
              .fetch("entries")
              .map { |entry| entry.fetch("url") }
          ensure
            session.detach
          end
        end
      expect(history_urls.any? { |url| url.include?("previous-example=1") }).to eq(false)
    end

    it "discards user changes to native console functions" do
      visit "/latest"
      page.execute_script("console.warn = () => {}")

      Capybara.reset_sessions!
      visit "/latest"

      expect(page.evaluate_script("console.warn.toString().includes('[native code]')")).to eq(true)
    end

    it "uses a fresh page after a custom initialization script" do
      visit "/latest"
      page.driver.with_playwright_page do |browser_page|
        browser_page.add_init_script(script: "window.applicationRestartCustomScript = true")
      end
      page.refresh
      expect(page.evaluate_script("window.applicationRestartCustomScript")).to eq(true)

      Capybara.reset_sessions!
      visit "/latest"

      expect(page.evaluate_script("window.applicationRestartCustomScript === undefined")).to eq(
        true,
      )
    end

    it "honors the requested clock and timezone",
       time: Time.utc(2020, 1, 2, 3, 4),
       timezone: "Asia/Tokyo" do
      visit "/latest"

      expect(page.evaluate_script("new Date().getUTCFullYear()")).to eq(2020)
      expect(page.evaluate_script("Intl.DateTimeFormat().resolvedOptions().timeZone")).to eq(
        "Asia/Tokyo",
      )
    end
  end

  describe "#resize_window_to" do
    it "preserves fixture authentication when resizing before the next visit" do
      visit "/latest"
      Capybara.reset_sessions!
      sign_in(user)

      page.current_window.resize_to(1800, 1000)
      visit "/latest"

      expect(page.current_window.size).to eq([1800, 1000])
      observe_browser do |observed_page|
        expect(
          observed_page.evaluate("() => window.Discourse.lookup('service:current-user').username"),
        ).to eq(user.username)
      end
    end
  end

  describe "#sign_in" do
    it "authenticates anonymous and retained-user sessions through actual cookies" do
      previous_forgery_protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      expect(ApplicationController.allow_forgery_protection).to eq(true)
      post = Fabricate(:post)
      topic_page = PageObjects::Pages::Topic.new
      topic_page.visit_topic(post.topic)
      fixture_path = URI(page.current_url).request_uri
      Capybara.reset_sessions!
      expect(page.driver).to be_application_restart_pending

      sign_in(user)
      expect(page).to have_current_path(fixture_path)
      topic_page.visit_topic(post.topic)

      observe_browser do |observed_page|
        expect(
          observed_page.evaluate("() => window.Discourse.lookup('service:current-user').username"),
        ).to eq(user.username)
      end
      observe_browser do |observed_page|
        expect(observed_page.evaluate(<<~JAVASCRIPT)).to eq(
          () => ({
            meta_type: typeof document.head.querySelector('meta[name=csrf-token]')?.content,
            session_type: typeof window.Discourse.lookup('service:session').csrfToken,
          })
        JAVASCRIPT
          "meta_type" => "string",
          "session_type" => "string",
        )
      end
      first_token =
        observe_browser do |browser_page|
          session = browser_page.context.new_cdp_session(browser_page)
          begin
            session
              .send_message("Network.getCookies", params: { urls: [browser_page.url] })
              .fetch("cookies")
              .find { |cookie| cookie["name"] == Auth::DefaultCurrentUserProvider::TOKEN_COOKIE }
              &.fetch("value")
          ensure
            session.detach
          end
        end
      expect(first_token).to be_present
      observe_browser do |observed_page|
        previous_owner = observed_page.evaluate_handle("() => window.Discourse")
        fixture_path = URI(page.current_url).request_uri
        Capybara.reset_sessions!
        expect(page.driver).to be_application_restart_pending

        sign_in(other_user)
        expect(page).to have_current_path(fixture_path)
        topic_page.visit_topic(post.topic)

        expect(
          previous_owner.evaluate("(owner) => owner.isDestroyed && owner !== window.Discourse"),
        ).to eq(true)
        expect(
          observed_page.evaluate("() => window.Discourse.lookup('service:current-user').username"),
        ).to eq(other_user.username)
      end
      second_token =
        observe_browser do |browser_page|
          session = browser_page.context.new_cdp_session(browser_page)
          begin
            session
              .send_message("Network.getCookies", params: { urls: [browser_page.url] })
              .fetch("cookies")
              .find { |cookie| cookie["name"] == Auth::DefaultCurrentUserProvider::TOKEN_COOKIE }
              &.fetch("value")
          ensure
            session.detach
          end
        end
      expect(second_token).to be_present
      expect(second_token == first_token).to eq(false)
      observe_browser do |observed_page|
        expect(observed_page.evaluate(<<~JAVASCRIPT)).to eq(
          () => ({
            meta_type: typeof document.head.querySelector('meta[name=csrf-token]')?.content,
            session_type: typeof window.Discourse.lookup('service:session').csrfToken,
          })
        JAVASCRIPT
          "meta_type" => "string",
          "session_type" => "string",
        )
      end
      topic_page.click_post_action_button(post, :bookmark)
      expect(topic_page).to have_post_bookmarked(post, with_reminder: false)
      expect(Bookmark.exists?(bookmarkable: post, user: other_user)).to eq(true)
      expect(Bookmark.exists?(bookmarkable: post, user: user)).to eq(false)
      page.refresh
      expect(topic_page).to have_post_bookmarked(post, with_reminder: false)
    ensure
      ActionController::Base.allow_forgery_protection = previous_forgery_protection
    end

    it "reports rejected fixture authentication without retrying the request" do
      user.update!(active: false)
      visit "/latest"
      Capybara.reset_sessions!
      expect(page.driver).to be_application_restart_pending
      requests = []
      listener =
        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
          requests << payload if payload[:action] == "become"
        end

      expect { sign_in(user) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)

      expect(requests.length).to eq(1)
      expect(requests.first[:status]).to eq(403)
      visit "/latest"
      expect(
        page.evaluate_script("window.Discourse.lookup('service:current-user') === null"),
      ).to eq(true)
      observe_browser { |observed_page| expect(observed_page.evaluate(<<~JAVASCRIPT)).to eq(true) }
          () => !document.head.querySelector('meta[name=csrf-token]') && window.Discourse.lookup('service:session').csrfToken === undefined
        JAVASCRIPT
    ensure
      ActiveSupport::Notifications.unsubscribe(listener) if listener
    end
  end
end
