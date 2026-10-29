# frozen_string_literal: true

RSpec.describe "Navigate with mobile tab bar", mobile: true do
  fab!(:current_user) { Fabricate(:admin, username: "alice", refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, username: "bob", refresh_auto_groups: true) }

  let(:tab_bar) { PageObjects::Components::MobileTabBar.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }
  let(:admin_menu) { ".sidebar-hamburger-dropdown .sidebar-sections.admin-panel" }
  let(:admin_page) { ".admin-menu .sidebar-panel-page" }
  let(:forum_menu) do
    ".sidebar-hamburger-dropdown .sidebar-section-wrapper[data-section-name='community']"
  end

  before do
    SiteSetting.enable_mobile_tab_bar = true
    SiteSetting.chat_enabled = false if SiteSetting.respond_to?(:chat_enabled)
    SiteSetting.sidebar_user_navigation = true
    SiteSetting.hide_new_user_profiles = false
    sign_in(current_user)
  end

  it "takes the user back to where they left each section" do
    visit("/latest")

    expect(tab_bar).to have_tabs("main", "admin")
    expect(tab_bar).to have_active_tab("main")
    expect(page).to have_no_css(".hamburger-dropdown")

    tab_bar.click_tab("admin")

    expect(page).to have_current_path("/admin/menu")
    expect(tab_bar).to have_active_tab("admin")

    find("#{admin_page} .sidebar-section-link", text: "Users").click

    expect(page).to have_current_path(%r{\A/admin/users})

    tab_bar.click_tab("main")

    expect(page).to have_current_path("/latest")

    tab_bar.click_tab("admin")

    expect(page).to have_current_path(%r{\A/admin/users})

    tab_bar.click_tab("admin")

    expect(page).to have_current_path("/admin/menu")
  end

  it "opens the forum's menu from sections that hold their navigation on their own page" do
    visit("/admin/menu")

    expect(page).to have_css("#{admin_page} .sidebar-section-link", text: "Dashboard")

    tab_bar.open_menu

    expect(page).to have_css(forum_menu)
    expect(page).to have_no_css(admin_menu)
    expect(page).to have_css("#{admin_page} .sidebar-section-link", text: "Dashboard")
  end

  it "leaves links to topics and to sections with their own tab out of the menu" do
    visit("/latest")

    tab_bar.open_menu

    expect(page).to have_css(forum_menu)
    expect(page).to have_css("#{forum_menu} .sidebar-section-link[data-link-name='review']")
    expect(page).to have_css("#{forum_menu} .sidebar-section-link[data-link-name='invite']")
    expect(page).to have_no_css(".sidebar-section-link[data-link-name='everything']")
    expect(page).to have_no_css(".sidebar-section-link[data-link-name='admin']")
  end

  it "offers the user's drafts from the create button" do
    Draft.set(current_user, Draft::NEW_TOPIC, 0, { reply: "an unfinished thought" }.to_json)
    current_user.user_stat.update!(draft_count: 1)

    visit("/latest")

    tab_bar.click_create

    expect(tab_bar).to have_create_actions("New topic", "New personal message", "Drafts (1)")

    tab_bar.click_create_action("Drafts (1)")

    expect(page).to have_current_path("/u/#{current_user.username}/activity/drafts")
  end

  it "lets the user start a topic in the category they're looking at from the create button" do
    category = Fabricate(:category)
    visit(category.url)

    expect(page).to have_css(".navigation-container")
    expect(page).to have_no_css("#create-topic")

    tab_bar.click_create

    expect(tab_bar).to have_create_actions("New topic", "New personal message")

    tab_bar.click_create_action("New topic")

    expect(page).to have_css("#reply-control.open")
    expect(PageObjects::Components::SelectKit.new(".category-chooser")).to have_selected_value(
      category.id,
    )
  end

  it "closes the section menu when the user starts something new" do
    visit("/latest")

    tab_bar.open_menu

    expect(page).to have_css(forum_menu)

    tab_bar.click_create
    tab_bar.click_create_action("New personal message")

    expect(page).to have_no_css(".sidebar-hamburger-dropdown")
    expect(page).to have_css("#reply-control.open .users-input")
  end

  it "takes the user from a topic back to the list they opened it from when they tap the current tab" do
    category = Fabricate(:category)
    topic = Fabricate(:post, topic: Fabricate(:topic, category:)).topic
    visit(category.url)

    PageObjects::Components::TopicList.new.visit_topic(topic)

    expect(page).to have_current_path(%r{\A/t/})
    expect(page).to have_css("html.mobile-tab-bar-nested")

    tab_bar.click_tab("main")

    expect(page).to have_current_path(category.url)
  end

  it "shows the full logo on a section's top level and a back button below it" do
    category = Fabricate(:category)
    topic = Fabricate(:post, topic: Fabricate(:topic, category:)).topic
    visit(category.url)

    expect(page).to have_css(".d-header .title:not(.title--minimized)")
    expect(page).to have_no_css(".mobile-tab-bar-back")

    PageObjects::Components::TopicList.new.visit_topic(topic)

    expect(page).to have_css(".mobile-tab-bar-back")
    expect(page).to have_css(".d-header .extra-info-wrapper", text: topic.title)
    expect(page).to have_no_css(".d-header .title--minimized", visible: :visible)

    find(".mobile-tab-bar-back").click

    expect(page).to have_current_path(category.url)

    visit("/admin/users")

    expect(page).to have_css(".mobile-tab-bar-back")
    expect(page).to have_css(".d-header .mobile-tab-bar-title", text: "Users")
    expect(page).to have_no_css(".d-page-header__title", visible: :visible)

    find(".mobile-tab-bar-back").click

    expect(page).to have_current_path("/admin/menu")
    expect(page).to have_no_css(".mobile-tab-bar-back")
    expect(page).to have_css(".d-header .title:not(.title--minimized)")
  end

  it "takes the user to search from the header" do
    visit("/latest")

    find(".d-header-icons .search-dropdown").click

    expect(page).to have_current_path("/search")
    expect(tab_bar).to have_active_tab("main")
  end

  it "keeps profile navigation on the page so the menu stays with the active tab" do
    visit("/u/bob/summary")

    expect(tab_bar).to have_active_tab("main")
    expect(page).to have_css(".user-navigation-primary")

    visit("/u/alice/summary")

    expect(page).to have_css(".user-navigation-primary")

    tab_bar.open_menu

    expect(page).to have_css(forum_menu)
  end

  it "keeps notifications and the profile tab together in the user menu" do
    visit("/latest")

    expect(page).to have_css("#toggle-current-user img.avatar")

    user_menu.open

    expect(page).to have_css("#user-menu-button-all-notifications")
    expect(page).to have_css("#user-menu-button-profile")
  end

  it "gives members without other sections the forum tab" do
    sign_in(other_user)

    visit("/latest")

    expect(tab_bar).to have_tabs("main")
    expect(page).to have_css(".mobile-tab-bar__create")
    expect(page).to have_css("#toggle-current-user img.avatar")
    expect(page).to have_no_css(".hamburger-dropdown")
  end
end
