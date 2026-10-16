# frozen_string_literal: true

RSpec.describe "Glimmer Header" do
  let(:header) { PageObjects::Pages::Header.new }
  let(:search) { PageObjects::Pages::Search.new }

  fab!(:current_user, :user)
  fab!(:topic)

  it "renders basics" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("header.d-header").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("#site-logo").filter(visible: true)).not_to have_count(0)
  end

  it "displays sign up button" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("button.sign-up-button").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("button.login-button").filter(visible: true)).not_to have_count(0)

    browser_root.locator("button.sign-up-button").filter(visible: true).click
    expect(browser_root.locator(".signup-fullpage").filter(visible: true)).not_to have_count(0)
  end

  it "displays login button" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("button.sign-up-button").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("button.login-button").filter(visible: true)).not_to have_count(0)

    browser_root.locator("button.login-button").filter(visible: true).click
    expect(browser_root.locator(".login-fullpage").filter(visible: true)).not_to have_count(0)
  end

  it "shows login button when login required" do
    SiteSetting.login_required = true

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("button.login-button").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("button.sign-up-button").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("#search-button").filter(visible: true)).to have_count(0)
    expect(browser_root.locator("button.btn-sidebar-toggle").filter(visible: true)).to have_count(0)
  end

  it "renders unread notifications count when user's notifications count is updated" do
    Fabricate(
      :notification,
      user: current_user,
      high_priority: true,
      read: false,
      created_at: 8.minutes.ago,
    )

    sign_in(current_user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(".header-dropdown-toggle.current-user .unread-notifications").filter(
        visible: true,
      ),
    ).to contain_text([browser_text_pattern("1")], useInnerText: true)
  end

  it "doesn't show pending reviewables count for non-legacy navigation menu" do
    SiteSetting.navigation_menu = "sidebar"
    current_user.update!(admin: true)
    Fabricate(:reviewable)

    sign_in(current_user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(".hamburger-dropdown .badge-notification").filter(visible: true),
    ).to have_count(0)
  end

  it "closes revamped menu when clicking outside" do
    sign_in(current_user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true).click
    expect(browser_root.locator(".user-menu.revamped").filter(visible: true)).not_to have_count(0)
    browser_root.locator("header.d-header").filter(visible: true).click
    expect(browser_root.locator(".user-menu.revamped").filter(visible: true)).to have_count(0)
  end

  it "closes menu-panel when keyboard focus leaves it" do
    sign_in(current_user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true).click
    browser_root
      .locator("##{header.active_element_id}")
      .filter(visible: true)
      .press(%w[Shift Tab].join("+"))
    expect(browser_root.locator(".user-menu.revamped").filter(visible: true)).to have_count(0)
  end

  it "automatically focuses the first link in the hamburger panel" do
    SiteSetting.navigation_menu = "header dropdown"

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root.locator("#toggle-hamburger-menu").filter(visible: true).click
    expect(browser_root.locator(".panel-body").filter(visible: true)).not_to have_count(0)
    first_link = browser_root.locator(".panel-body a").filter(visible: true).first
    first_link_href =
      first_link.evaluate(
        "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
        arg: "href",
      )
    focused_element_href =
      browser_page.evaluate("function(arguments) { return document.activeElement.href }", arg: [])

    expect(focused_element_href).to eq(first_link_href)
  end

  it "sets header's height css property" do
    sign_in(current_user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    header.resize_element(".d-header", 90)
    wait_for(timeout: 100) do
      header.get_computed_style_value(".d-header", "--header-offset") == "90px"
    end
    expect(header.get_computed_style_value(".d-header", "--header-offset")).to eq("90px")

    header.resize_element(".d-header", 60)
    wait_for(timeout: 100) do
      header.get_computed_style_value(".d-header", "--header-offset") == "60px"
    end
    expect(header.get_computed_style_value(".d-header", "--header-offset")).to eq("60px")
  end

  it "moves focus between tabs using arrow keys" do
    sign_in(current_user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true).click
    expect(header.active_element_id).to eq("user-menu-button-all-notifications")

    browser_root.locator("##{header.active_element_id}").filter(visible: true).press("ArrowDown")
    expect(header.active_element_id).to eq("user-menu-button-replies")

    4.times do
      browser_root.locator("##{header.active_element_id}").filter(visible: true).press("ArrowDown")
    end
    expect(header.active_element_id).to eq("user-menu-button-profile")

    browser_root.locator("##{header.active_element_id}").filter(visible: true).press("ArrowDown")
    expect(header.active_element_id).to eq("user-menu-button-all-notifications")

    browser_root.locator("##{header.active_element_id}").filter(visible: true).press("ArrowUp")
    expect(header.active_element_id).to eq("user-menu-button-profile")
  end

  it "prioritizes new personal messages bubble over unseen reviewables and regular notifications bubbles" do
    Fabricate(:private_message_notification, user: current_user)
    Fabricate(
      :notification,
      user: current_user,
      high_priority: true,
      read: false,
      created_at: 8.minutes.ago,
    )

    sign_in(current_user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(
        ".header-dropdown-toggle.current-user .badge-notification.unread-notifications",
      ).filter(visible: true),
    ).to have_count(0)
    expect(
      browser_root.locator(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-reviewables",
      ).filter(visible: true),
    ).to have_count(0)

    expect(
      browser_root.locator(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms",
      ).filter(visible: true),
    ).not_to have_count(0)
    expect(browser_root.locator(".d-icon-envelope").filter(visible: true)).not_to have_count(0)
    expect(
      browser_root
        .locator(".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms")
        .filter(visible: true)
        .evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "title",
        ),
    ).to eq(I18n.t("js.notifications.tooltip.new_message_notification", count: 1))
  end

  it "prioritizes unseen reviewables bubble over regular notifications" do
    current_user.update!(admin: true)
    Fabricate(:reviewable)

    sign_in(current_user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(
        ".header-dropdown-toggle.current-user .badge-notification.unread-notifications",
      ).filter(visible: true),
    ).to have_count(0)
    expect(
      browser_root.locator(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-reviewables",
      ).filter(visible: true),
    ).not_to have_count(0)
    expect(
      browser_root.locator(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms",
      ).filter(visible: true),
    ).to have_count(0)
  end

  it "shows regular notifications bubble if there are neither new personal messages nor unseen reviewables" do
    Fabricate.times(
      3,
      :notification,
      user: current_user,
      high_priority: true,
      read: false,
      created_at: 8.minutes.ago,
    )

    sign_in(current_user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(
        ".header-dropdown-toggle.current-user .badge-notification.unread-notifications",
      ).filter(visible: true),
    ).to contain_text([browser_text_pattern("3")], useInnerText: true)
    expect(
      browser_root
        .locator(".header-dropdown-toggle.current-user .badge-notification.unread-notifications")
        .filter(visible: true)
        .evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "title",
        ),
    ).to eq(I18n.t("js.notifications.tooltip.regular", count: 3))
    expect(
      browser_root.locator(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-reviewables",
      ).filter(visible: true),
    ).to have_count(0)
    expect(
      browser_root.locator(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms",
      ).filter(visible: true),
    ).to have_count(0)
  end

  context "when resetting password" do
    fab!(:current_user, :user)

    it "does not show search, login, or signup buttons" do
      email_token =
        current_user.email_tokens.create!(
          email: current_user.email,
          scope: EmailToken.scopes[:password_reset],
        )

      browser_page
        .goto("/u/password-reset/#{email_token.token}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_root.locator("button.login-button").filter(visible: true)).to have_count(0)
      expect(browser_root.locator("button.sign-up-button").filter(visible: true)).to have_count(0)
      expect(
        browser_root.locator(".search-dropdown #search-button").filter(visible: true),
      ).to have_count(0)
    end
  end

  context "when logged in and login required" do
    fab!(:current_user, :user)

    it "displays current user when logged in and login required" do
      SiteSetting.login_required = true
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
      sign_in(current_user)

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_root.locator("button.login-button").filter(visible: true)).to have_count(0)
      expect(browser_root.locator("button.sign-up-button").filter(visible: true)).to have_count(0)
      expect(browser_root.locator("#search-button").filter(visible: true)).not_to have_count(0)
      expect(
        browser_root.locator("button.btn-sidebar-toggle").filter(visible: true),
      ).not_to have_count(0)
      expect(browser_root.locator("#current-user").filter(visible: true)).not_to have_count(0)
    end
  end

  describe "mobile topic-info" do
    fab!(:topic)
    fab!(:posts) { Fabricate.times(21, :post, topic: topic) }

    it "only shows when scrolled down", mobile: true do
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator("#topic-title").filter(visible: true)).not_to have_count(0) # Main topic title
      expect(
        browser_root.locator("header.d-header .auth-buttons .login-button").filter(visible: true),
      ).not_to have_count(0) # header buttons visible when no topic-info in header

      browser_page.evaluate(
        "function(arguments) { document.querySelector('#post_4').scrollIntoView() }",
        arg: [],
      )

      expect(
        browser_root.locator("header.d-header .auth-buttons .login-button").filter(visible: true),
      ).to have_count(0) # No header buttons
      expect(
        browser_root.locator("header.d-header .title-wrapper .topic-link").filter(visible: true),
      ).not_to have_count(0) # Title is shown in header

      browser_page.evaluate("function(arguments) { window.scrollTo(0, 0) }", arg: [])
      expect(browser_root.locator("#topic-title").filter(visible: true)).not_to have_count(0) # Main topic title
      expect(
        browser_root.locator("header.d-header .auth-buttons .login-button").filter(visible: true),
      ).not_to have_count(0) # header buttons visible when no topic-info in header
    end

    it "shows when navigating direct to a later post", mobile: true do
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}/4")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator("header.d-header .auth-buttons .login-button").filter(visible: true),
      ).to have_count(0) # No header buttons
      expect(
        browser_root.locator("header.d-header .title-wrapper .topic-link").filter(visible: true),
      ).not_to have_count(0) # Title is shown in header
    end

    it "shows when jumping from OP to much later post", mobile: true do
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator("#topic-title").filter(visible: true)).not_to have_count(0) # Main topic title
      expect(
        browser_root.locator("header.d-header .auth-buttons .login-button").filter(visible: true),
      ).not_to have_count(0) # header buttons visible when no topic-info in header

      browser_page.evaluate(
        "function(arguments) { #{"Discourse.visit('/t/#{topic.slug}/#{topic.id}/21');"} }",
        arg: [],
      )

      expect(browser_root.locator("#post_21").filter(visible: true)).not_to have_count(0)

      expect(
        browser_root.locator("header.d-header .auth-buttons .login-button").filter(visible: true),
      ).to have_count(0) # No header buttons
      expect(
        browser_root.locator("header.d-header .title-wrapper .topic-link").filter(visible: true),
      ).not_to have_count(0) # Title is shown in header
    end

    it "shows and hides do-not-disturb icon" do
      sign_in current_user
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".d-header .do-not-disturb-background").filter(visible: true),
      ).to have_count(0)

      current_user.publish_do_not_disturb(ends_at: 1.hour.from_now)

      try_until_success(reason: "Relies on messagebus updates") do
        expect(
          browser_root.locator(".d-header .do-not-disturb-background").filter(visible: true),
        ).not_to have_count(0)
      end

      current_user.publish_do_not_disturb(ends_at: 1.second.from_now)

      expect(
        browser_root.locator(".d-header .do-not-disturb-background").filter(visible: true),
      ).to have_count(0)
    end
  end
end
