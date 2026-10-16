# frozen_string_literal: true

describe "Admin | Sidebar Navigation" do
  UNFILTERED_LINK_COUNT = 42

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
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(sidebar).to have_section("categories")
    sidebar.click_link_in_section("community", "admin")
    expect(browser_page).to have_url("/admin")
    expect(sidebar).to RSpecPredicates.be_visible
    expect(sidebar).to have_no_section("categories")
    expect(browser_root.locator(".admin-main-nav").filter(visible: true)).to have_count(0)

    sidebar.click_back_to_forum
    expect(browser_page).to have_url("/latest")
    expect(sidebar).to have_no_section("admin-root")
  end

  it "goes back to exactly the same page when clicking back to forum" do
    browser_page.goto("/hot").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.click_link_in_section("community", "admin")

    sidebar.click_back_to_forum
    expect(browser_page).to have_url("/hot")
  end

  context "with subfolder" do
    before { set_subfolder "/discuss" }

    it "navigates back to homepage correctly" do
      browser_page.goto("/discuss/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      sidebar.click_back_to_forum
      expect(browser_page).to have_url("/discuss/")
    end
  end

  it "displays the panel header" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(sidebar).to have_panel_header
  end

  it "collapses sections by default" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    links =
      browser_root
        .locator(".sidebar-section-link-content-text")
        .filter(visible: true)
        .tap { |elements| elements.first.wait_for(state: "visible") }
        .all
    expect(links.map { |element| element.inner_text.strip }).to eq(
      [
        I18n.t("admin_js.admin.dashboard.title"),
        I18n.t("admin_js.admin.config.users.title"),
        I18n.t("admin_js.admin.config.groups.title"),
        I18n.t("admin_js.admin.config.site_settings.title"),
        I18n.t("js.sidebar.sections.community.links.review.content"),
        I18n.t("admin_js.admin.config.whats_new.title"),
        I18n.t("admin_js.admin.config.upcoming_changes.title"),
      ],
    )
  end

  context "when on mobile" do
    it "shows the admin sidebar links in the header-dropdown when navigating to an admin route and hides them when leaving",
       mobile: true do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      sidebar_dropdown.click
      expect(sidebar).to have_section("community")
      sidebar.click_link_in_section("community", "admin")
      expect(browser_page).to have_url("/admin")
      sidebar_dropdown.click
      expect(sidebar).to have_no_section("community")
      expect(browser_root.locator(".admin-main-nav").filter(visible: true)).to have_count(0)

      sidebar.click_back_to_forum
      expect(browser_page).to have_url("/latest")

      sidebar_dropdown.click
      expect(sidebar).to have_no_section("admin-root")
    end
  end

  it "allows sections to be expanded" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.toggle_all_sections
    expect(
      browser_root
        .locator(".sidebar-section-link-content-text")
        .filter(visible: true)
        .nth(UNFILTERED_LINK_COUNT - 1),
    ).to be_attached

    sidebar.toggle_all_sections
    expected_links = [
      I18n.t("admin_js.admin.dashboard.title"),
      I18n.t("admin_js.admin.config.users.title"),
      I18n.t("admin_js.admin.config.groups.title"),
      I18n.t("admin_js.admin.config.site_settings.title"),
      I18n.t("js.sidebar.sections.community.links.review.content"),
      I18n.t("admin_js.admin.config.whats_new.title"),
      I18n.t("admin_js.admin.config.upcoming_changes.title"),
    ]
    expect(
      browser_root.locator(".sidebar-section-link-content-text").filter(visible: true),
    ).to have_count(expected_links.length)
    expect(
      browser_root
        .locator(".sidebar-section-link-content-text")
        .filter(visible: true)
        .tap { |elements| elements.first.wait_for(state: "visible") }
        .all
        .map { |element| element.inner_text.strip },
    ).to eq(expected_links)

    sidebar.toggle_all_sections
    expect(
      browser_root
        .locator(".sidebar-section-link-content-text")
        .filter(visible: true)
        .nth(UNFILTERED_LINK_COUNT - 1),
    ).to be_attached
  end

  it "highlights the 'Themes and components' link when either the themes, themes components or theme site settings admin page is visited" do
    browser_page
      .goto("/admin/config/customize/themes")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(
        '.sidebar-section-link-wrapper[data-list-item-name="admin_themes_and_components"] a.active',
      ).filter(visible: true),
    ).not_to have_count(0)

    browser_root
      .locator("[id=#{"Components".to_s.to_json}], [name=#{"Components".to_s.to_json}]")
      .or(browser_root.get_by_role("link", name: "Components", exact: true))
      .filter(visible: true)
      .click

    expect(browser_page).to have_url("/admin/config/customize/components")

    expect(
      browser_root.locator(
        '.sidebar-section-link-wrapper[data-list-item-name="admin_themes_and_components"] a.active',
      ).filter(visible: true),
    ).not_to have_count(0)

    browser_root
      .locator(
        "[id=#{"Theme site settings".to_s.to_json}], [name=#{"Theme site settings".to_s.to_json}]",
      )
      .or(browser_root.get_by_role("link", name: "Theme site settings"))
      .filter(visible: true)
      .click

    expect(browser_page).to have_url("/admin/config/customize/theme-site-settings")

    expect(
      browser_root.locator(
        '.sidebar-section-link-wrapper[data-list-item-name="admin_themes_and_components"] a.active',
      ).filter(visible: true),
    ).not_to have_count(0)
  end

  it "highlights the 'All site settings' link on the all settings page" do
    browser_page
      .goto("/admin/site_settings/category/all_results")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(
        '.sidebar-section-link-wrapper[data-list-item-name="admin_all_site_settings"] a.active',
      ).filter(visible: true),
    ).not_to have_count(0)
  end

  it "does not show the button to customize sidebar sections, that is only supported in the main panel" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(sidebar).to have_add_section_button
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(sidebar).to have_no_add_section_button
  end

  it "displays limited links for moderator" do
    sign_in(moderator)
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.toggle_all_sections

    expect(browser_root.locator(".sidebar-section--collapsed").filter(visible: true)).to have_count(
      0,
    )

    links =
      browser_root
        .locator(".sidebar-section-link-content-text")
        .filter(visible: true)
        .tap { |elements| elements.first.wait_for(state: "visible") }
        .all
    expect(links.map { |element| element.inner_text.strip }).to eq(
      [
        I18n.t("admin_js.admin.dashboard.title"),
        I18n.t("admin_js.admin.config.users.title"),
        I18n.t("admin_js.admin.config.groups.title"),
        I18n.t("js.sidebar.sections.community.links.review.content"),
        I18n.t("admin_js.admin.config.whats_new.title"),
        I18n.t("admin_js.admin.config.reports.title"),
        I18n.t("admin_js.admin.config.watched_words.title"),
        I18n.t("admin_js.admin.config.staff_action_logs.title"),
      ],
    )

    filter.filter("watched")
    links =
      browser_root
        .locator(".sidebar-section-link-content-text")
        .filter(visible: true)
        .tap { |elements| elements.first.wait_for(state: "visible") }
        .all
    expect(links.count).to eq(1)
    expect(links.map { |element| element.inner_text.strip }).to eq(["Watched words"])
  end
end
