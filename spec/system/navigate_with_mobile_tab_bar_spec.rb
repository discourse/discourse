# frozen_string_literal: true

RSpec.describe "Navigate with mobile tab bar", mobile: true do
  fab!(:current_user) { Fabricate(:admin, username: "alice", refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, username: "bob", refresh_auto_groups: true) }

  let(:tab_bar) { PageObjects::Components::MobileTabBar.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }
  let(:admin_menu) { ".sidebar-hamburger-dropdown .sidebar-sections.admin-panel" }
  let(:forum_menu) do
    ".sidebar-hamburger-dropdown .sidebar-section-wrapper[data-section-name='community']"
  end

  before do
    SiteSetting.enable_mobile_tab_bar = true
    SiteSetting.sidebar_user_navigation = true
    SiteSetting.hide_new_user_profiles = false
    sign_in(current_user)
  end

  it "takes the user back to where they left each section" do
    visit("/latest")

    expect(tab_bar).to have_tabs("main", "search", "admin")
    expect(tab_bar).to have_active_tab("main")
    expect(page).to have_no_css(".hamburger-dropdown")

    tab_bar.click_tab("admin")

    expect(page).to have_current_path("/admin")
    expect(tab_bar).to have_active_tab("admin")

    tab_bar.open_section_menu
    find("#{admin_menu} .sidebar-section-link", text: "Users").click

    expect(page).to have_current_path(%r{\A/admin/users})

    tab_bar.click_tab("main")

    expect(page).to have_current_path("/latest")

    tab_bar.click_tab("admin")

    expect(page).to have_current_path(%r{\A/admin/users})

    tab_bar.click_tab("admin")

    expect(page).to have_current_path("/admin")
  end

  it "lets the user open the current section's menu and start something new from it" do
    visit("/latest")

    tab_bar.open_section_menu

    expect(page).to have_css(forum_menu)
    find(".sidebar-menu-action__button").click

    expect(page).to have_no_css(".sidebar-hamburger-dropdown")
    expect(page).to have_css("#reply-control.open")
  end

  it "takes the user from a topic back to the list they opened it from when they tap the current tab" do
    category = Fabricate(:category)
    topic = Fabricate(:post, topic: Fabricate(:topic, category:)).topic
    visit(category.url)

    PageObjects::Components::TopicList.new.visit_topic(topic)

    expect(page).to have_current_path(%r{\A/t/})
    expect(page).to have_css(".header-section-nav")
    expect(page).to have_css("html.mobile-tab-bar-nested")

    tab_bar.click_tab("main")

    expect(page).to have_current_path(category.url)
  end

  it "takes the user to search from its tab" do
    visit("/latest")

    tab_bar.click_tab("search")

    expect(page).to have_current_path("/search")
    expect(tab_bar).to have_active_tab("search")

    find("input.search-query").fill_in(with: "kittens\n")
    expect(page).to have_current_path("/search?q=kittens")

    tab_bar.click_tab("main")
    tab_bar.click_tab("search")

    expect(page).to have_current_path("/search")
    expect(page).to have_css("input.search-query:focus")
  end

  it "keeps profile navigation on the page so the menu stays with the active tab" do
    visit("/u/bob/summary")

    expect(tab_bar).to have_active_tab("main")
    expect(page).to have_css(".user-navigation-primary")

    visit("/u/alice/summary")

    expect(page).to have_css(".user-navigation-primary")

    tab_bar.open_section_menu

    expect(page).to have_css(forum_menu)
  end

  it "keeps notifications and the profile tab together in the user menu" do
    visit("/latest")

    expect(page).to have_css("#toggle-current-user img.avatar")

    user_menu.open

    expect(page).to have_css("#user-menu-button-all-notifications")
    expect(page).to have_css("#user-menu-button-profile")
  end

  it "gives members without other sections the forum and search tabs" do
    sign_in(other_user)

    visit("/latest")

    expect(tab_bar).to have_tabs("main", "search")
    expect(page).to have_css("#toggle-current-user img.avatar")
    expect(page).to have_no_css(".hamburger-dropdown")
  end
end
