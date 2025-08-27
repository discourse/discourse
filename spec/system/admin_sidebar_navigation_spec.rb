# frozen_string_literal: true

describe "Admin | Sidebar Navigation", type: :system do
  UNFILTERED_LINK_COUNT = 41

  fab!(:admin)
  fab!(:moderator)

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:sidebar_dropdown) { PageObjects::Components::SidebarHeaderDropdown.new }
  let(:filter) { PageObjects::Components::Filter.new }

  before do
    SiteSetting.navigation_menu = "sidebar"

    sign_in(admin)
  end

  it "shows the sidebar when navigating to an admin route and hides it when leaving" do
    visit("/latest")
    expect(sidebar).to have_section("categories")
    sidebar.click_link_in_section("community", "admin")
    expect(page).to have_current_path("/admin")
    expect(sidebar).to be_visible
    expect(sidebar).to have_no_section("categories")
    expect(page).to have_no_css(".admin-main-nav")

    sidebar.click_back_to_forum
    expect(page).to have_current_path("/latest")
    expect(sidebar).to have_no_section("admin-root")
  end

  it "goes back to exactly the same page when clicking back to forum" do
    visit("/hot")

    sidebar.click_link_in_section("community", "admin")

    sidebar.click_back_to_forum
    expect(page).to have_current_path("/hot")
  end

  context "with subfolder" do
    before { set_subfolder "/discuss" }

    it "navigates back to homepage correctly" do
      visit("/discuss/admin")

      sidebar.click_back_to_forum
      expect(page).to have_current_path("/discuss/")
    end
  end

  it "displays the panel header" do
    visit("/admin")
    expect(sidebar).to have_panel_header
  end

  it "collapses sections by default" do
    visit("/admin")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.map(&:text)).to eq(
      [
        I18n.t("admin_js.admin.dashboard.title"),
        I18n.t("admin_js.admin.config.users.title"),
        I18n.t("admin_js.admin.config.groups.title"),
        I18n.t("admin_js.admin.config.site_settings.title"),
        I18n.t("admin_js.admin.config.whats_new.title"),
      ],
    )
  end

  context "when on mobile" do
    it "shows the admin sidebar links in the header-dropdown when navigating to an admin route and hides them when leaving",
       mobile: true do
      visit("/latest")
      sidebar_dropdown.click
      expect(sidebar).to have_section("community")
      sidebar.click_link_in_section("community", "admin")
      expect(page).to have_current_path("/admin")
      sidebar_dropdown.click
      expect(sidebar).to have_no_section("community")
      expect(page).to have_no_css(".admin-main-nav")

      sidebar.click_back_to_forum
      expect(page).to have_current_path("/latest")

      sidebar_dropdown.click
      expect(sidebar).to have_no_section("admin-root")
    end
  end

  it "allows sections to be expanded" do
    visit("/admin")
    sidebar.toggle_all_sections
    expect(page).to have_selector(
      ".sidebar-section-link-content-text",
      minimum: UNFILTERED_LINK_COUNT,
    )

    sidebar.toggle_all_sections
    expect(page).to have_selector(".sidebar-section-link-content-text", count: 5)
    expect(all(".sidebar-section-link-content-text").map(&:text)).to eq(
      [
        I18n.t("admin_js.admin.dashboard.title"),
        I18n.t("admin_js.admin.config.users.title"),
        I18n.t("admin_js.admin.config.groups.title"),
        I18n.t("admin_js.admin.config.site_settings.title"),
        I18n.t("admin_js.admin.config.whats_new.title"),
      ],
    )

    sidebar.toggle_all_sections
    expect(page).to have_selector(
      ".sidebar-section-link-content-text",
      minimum: UNFILTERED_LINK_COUNT,
    )
  end

  it "highlights the 'Themes and components' link when the themes page is visited" do
    visit("/admin/config/customize/themes")
    expect(page).to have_css(
      '.sidebar-section-link-wrapper[data-list-item-name="admin_themes_and_components"] a.active',
    )
  end

  # TODO(osama) unskip this test when the "Themes and components" link is
  # changed to the new config customize page
  xit "highlights the 'Themes and components' link when the components page is visited" do
    visit("/admin/config/customize/components")
    expect(page).to have_css(
      '.sidebar-section-link-wrapper[data-list-item-name="admin_themes_and_components"] a.active',
    )
  end

  it "does not show the button to customize sidebar sections, that is only supported in the main panel" do
    visit("/")
    expect(sidebar).to have_add_section_button
    visit("/admin")
    expect(sidebar).to have_no_add_section_button
  end

  it "displays limited links for moderator" do
    sign_in(moderator)
    visit("/admin")

    sidebar.toggle_all_sections

    expect(page).to have_no_css(".sidebar-section--collapsed")

    links = page.all(".sidebar-section-link-content-text")
    expect(links.map(&:text)).to eq(
      [
        I18n.t("admin_js.admin.dashboard.title"),
        I18n.t("admin_js.admin.config.users.title"),
        I18n.t("admin_js.admin.config.groups.title"),
        I18n.t("admin_js.admin.config.whats_new.title"),
        I18n.t("admin_js.admin.config.reports.title"),
        I18n.t("admin_js.admin.config.watched_words.title"),
        I18n.t("admin_js.admin.config.staff_action_logs.title"),
      ],
    )

    filter.filter("watched")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.count).to eq(1)
    expect(links.map(&:text)).to eq(["Watched words"])
  end
end
