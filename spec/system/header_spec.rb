# frozen_string_literal: true

RSpec.describe "Glimmer Header", type: :system do
  let(:header) { PageObjects::Pages::Header.new }
  let(:search) { PageObjects::Pages::Search.new }
  fab!(:current_user) { Fabricate(:user) }
  fab!(:topic)

  it "renders basics" do
    visit "/"
    expect(page).to have_css("header.d-header")
    expect(page).to have_css("#site-logo")
  end

  it "displays sign up / login buttons" do
    visit "/"
    expect(page).to have_css("button.sign-up-button")
    expect(page).to have_css("button.login-button")

    find("button.sign-up-button").click
    expect(page).to have_css(".d-modal.create-account")

    header.click_outside

    find("button.login-button").click
    expect(page).to have_css(".d-modal.login-modal")
  end

  it "shows login button when login required" do
    SiteSetting.login_required = true

    visit "/"
    expect(page).to have_css("button.login-button")
    expect(page).to have_css("button.sign-up-button")
    expect(page).not_to have_css("#search-button")
    expect(page).not_to have_css("button.btn-sidebar-toggle")
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
    visit "/"
    expect(page).to have_selector(
      ".header-dropdown-toggle.current-user .unread-notifications",
      text: "1",
    )
  end

  it "doesn't show pending reviewables count for non-legacy navigation menu" do
    SiteSetting.navigation_menu = "sidebar"
    current_user.update!(admin: true)
    Fabricate(:reviewable)

    sign_in(current_user)
    visit "/"
    expect(page).not_to have_selector(".hamburger-dropdown .badge-notification")
  end

  it "closes revamped menu when clicking outside" do
    sign_in(current_user)
    visit "/"
    find(".header-dropdown-toggle.current-user").click
    expect(page).to have_selector(".user-menu.revamped")
    find("header.d-header").click
    expect(page).not_to have_selector(".user-menu.revamped")
  end

  it "closes menu-panel when keyboard focus leaves it" do
    sign_in(current_user)
    visit "/"
    find(".header-dropdown-toggle.current-user").click
    find("##{header.active_element_id}").send_keys(%i[shift tab])
    expect(page).not_to have_selector(".user-menu.revamped")
  end

  it "automatically focuses the first link in the hamburger panel" do
    SiteSetting.navigation_menu = "header dropdown"

    visit "/"

    find("#toggle-hamburger-menu").click
    expect(page).to have_selector(".panel-body")
    first_link = find(".panel-body a", match: :first)
    first_link_href = first_link[:href]
    focused_element_href = evaluate_script("document.activeElement.href")

    expect(focused_element_href).to eq(first_link_href)
  end

  it "sets header's height css property" do
    sign_in(current_user)
    visit "/"
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
    visit "/"
    find(".header-dropdown-toggle.current-user").click
    expect(header.active_element_id).to eq("user-menu-button-all-notifications")

    find("##{header.active_element_id}").send_keys(:arrow_down)
    expect(header.active_element_id).to eq("user-menu-button-replies")

    4.times { find("##{header.active_element_id}").send_keys(:arrow_down) }
    expect(header.active_element_id).to eq("user-menu-button-profile")

    find("##{header.active_element_id}").send_keys(:arrow_down)
    expect(header.active_element_id).to eq("user-menu-button-all-notifications")

    find("##{header.active_element_id}").send_keys(:arrow_up)
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
    visit "/"
    expect(page).not_to have_selector(
      ".header-dropdown-toggle.current-user .badge-notification.unread-notifications",
    )
    expect(page).not_to have_selector(
      ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-reviewables",
    )

    expect(page).to have_selector(
      ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms",
    )
    expect(page).to have_css(".d-icon-envelope")
    expect(
      find(".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms")[:title],
    ).to eq(I18n.t("js.notifications.tooltip.new_message_notification", count: 1))
  end

  it "prioritizes unseen reviewables bubble over regular notifications" do
    current_user.update!(admin: true)
    Fabricate(:reviewable)

    sign_in(current_user)
    visit "/"
    expect(page).not_to have_selector(
      ".header-dropdown-toggle.current-user .badge-notification.unread-notifications",
    )
    expect(page).to have_selector(
      ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-reviewables",
    )
    expect(page).not_to have_selector(
      ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms",
    )
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
    visit "/"
    expect(page).to have_selector(
      ".header-dropdown-toggle.current-user .badge-notification.unread-notifications",
      text: "3",
    )
    expect(
      find(".header-dropdown-toggle.current-user .badge-notification.unread-notifications")[:title],
    ).to eq(I18n.t("js.notifications.tooltip.regular", count: 3))
    expect(page).not_to have_selector(
      ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-reviewables",
    )
    expect(page).not_to have_selector(
      ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms",
    )
  end

  context "when resetting password" do
    fab!(:current_user) { Fabricate(:user) }

    it "does not show search, login, or signup buttons" do
      email_token =
        current_user.email_tokens.create!(
          email: current_user.email,
          scope: EmailToken.scopes[:password_reset],
        )

      visit "/u/password-reset/#{email_token.token}"
      expect(page).not_to have_css("button.login-button")
      expect(page).not_to have_css("button.sign-up-button")
      expect(page).not_to have_css(".search-dropdown #search-button")
    end
  end

  context "when logged in and login required" do
    fab!(:current_user) { Fabricate(:user) }

    it "displays current user when logged in and login required" do
      SiteSetting.login_required = true
      sign_in(current_user)

      visit "/"
      expect(page).not_to have_css("button.login-button")
      expect(page).not_to have_css("button.sign-up-button")
      expect(page).to have_css("#search-button")
      expect(page).to have_css("button.btn-sidebar-toggle")
      expect(page).to have_css("#current-user")
    end
  end

  context "when cmd + f keyboard shortcut pressed - when within a topic with 20+ posts" do
    before { sign_in(current_user) }
    fab!(:posts) { Fabricate.times(21, :post, topic: topic) }

    it "opens search on first press, and closes on the second" do
      visit "/t/#{topic.slug}/#{topic.id}"
      header.search_in_topic_keyboard_shortcut
      expect(search).to have_search_menu_visible
      header.search_in_topic_keyboard_shortcut
      expect(search).to have_no_search_menu_visible
    end
  end

  describe "mobile topic-info" do
    fab!(:topic)
    fab!(:posts) { Fabricate.times(21, :post, topic: topic) }

    it "only shows when scrolled down", mobile: true do
      visit "/t/#{topic.slug}/#{topic.id}"

      expect(page).to have_css("#topic-title") # Main topic title
      expect(page).to have_css("header.d-header .auth-buttons .login-button") # header buttons visible when no topic-info in header

      page.execute_script("document.querySelector('#post_4').scrollIntoView()")

      expect(page).not_to have_css("header.d-header .auth-buttons .login-button") # No header buttons
      expect(page).to have_css("header.d-header .title-wrapper .topic-link") # Title is shown in header

      page.execute_script("window.scrollTo(0, 0)")
      expect(page).to have_css("#topic-title") # Main topic title
      expect(page).to have_css("header.d-header .auth-buttons .login-button") # header buttons visible when no topic-info in header
    end

    it "shows when navigating direct to a later post", mobile: true do
      visit "/t/#{topic.slug}/#{topic.id}/4"

      expect(page).not_to have_css("header.d-header .auth-buttons .login-button") # No header buttons
      expect(page).to have_css("header.d-header .title-wrapper .topic-link") # Title is shown in header
    end

    it "shows when jumping from OP to much later post", mobile: true do
      visit "/t/#{topic.slug}/#{topic.id}"

      expect(page).to have_css("#topic-title") # Main topic title
      expect(page).to have_css("header.d-header .auth-buttons .login-button") # header buttons visible when no topic-info in header

      page.execute_script("Discourse.visit('/t/#{topic.slug}/#{topic.id}/21');")

      expect(page).to have_css("#post_21")

      expect(page).not_to have_css("header.d-header .auth-buttons .login-button") # No header buttons
      expect(page).to have_css("header.d-header .title-wrapper .topic-link") # Title is shown in header
    end

    it "shows and hides do-not-disturb icon" do
      sign_in current_user
      visit "/"

      header = find(".d-header")
      expect(header).not_to have_css(".do-not-disturb-background")

      current_user.publish_do_not_disturb(ends_at: 1.hour.from_now)
      expect(header).to have_css(".d-header .do-not-disturb-background")

      current_user.publish_do_not_disturb(ends_at: 1.second.from_now)

      expect(header).not_to have_css(".d-header .do-not-disturb-background")
    end
  end
end
