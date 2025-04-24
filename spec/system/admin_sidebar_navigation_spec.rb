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
    filter.click_back_to_forum
    expect(page).to have_current_path("/latest")
    expect(sidebar).to have_no_section("admin-root")
  end

  it "goes back to exactly the same page when clicking back to forum" do
    visit("/hot")

    sidebar.click_link_in_section("community", "admin")

    filter.click_back_to_forum
    expect(page).to have_current_path("/hot")
  end

  context "with subfolder" do
    before { set_subfolder "/discuss" }

    it "navigates back to homepage correctly" do
      visit("/discuss/admin")

      filter.click_back_to_forum
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
        I18n.t("admin_js.admin.config.search_everything.title"),
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
      filter.click_back_to_forum
      expect(page).to have_current_path("/latest")
      sidebar_dropdown.click
      expect(sidebar).to have_no_section("admin-root")
    end
  end

  it "allows links to be filtered" do
    visit("/admin")
    sidebar.toggle_all_sections

    expect(page).to have_selector(
      ".sidebar-section-link-content-text",
      minimum: UNFILTERED_LINK_COUNT,
    )
    expect(page).to have_no_css(".sidebar-no-results")
    all_links_count = page.all(".sidebar-section-link-content-text").count

    filter.filter("ie")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.map(&:text)).to eq(
      [
        I18n.t("admin_js.admin.config.content.title"),
        I18n.t("admin_js.admin.config.user_fields.title"),
        I18n.t("admin_js.admin.config.flags.title"),
        I18n.t("admin_js.admin.config.email.title"),
      ],
    )
    expect(page).to have_no_css(".sidebar-no-results")

    filter.filter("ieeee")
    expect(page).to have_no_css(".sidebar-section-link-content-text")
    expect(page).to have_css(".sidebar-no-results")

    filter.clear
    links = page.all(".sidebar-section-link-content-text")
    expect(links.count).to eq(all_links_count)
    expect(page).to have_no_css(".sidebar-no-results")
    expect(page).to have_css(".sidebar-sections__back-to-forum")

    # When match section title, display all links
    filter.filter("Email")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.map(&:text)).to eq(
      [
        I18n.t("admin_js.admin.config.email.title"),
        I18n.t("admin_js.admin.config.email_appearance.title"),
        I18n.t("admin_js.admin.config.email_logs.title"),
        I18n.t("admin_js.admin.config.staff_action_logs.title"),
      ],
    )
  end

  it "escapes the filtered expression for regex expressions" do
    visit("/admin")

    filter.filter(".*") # this shouldn't return any results if the expression was escaped
    expect(page).to have_no_css(".sidebar-section-link-content-text")
    expect(page).to have_css(".sidebar-no-results")
  end

  it "displays the no results description message correctly when the filter has no results" do
    visit("/admin")

    filter.filter("ieeee")
    expect(page).to have_no_css(".sidebar-section-link-content-text")
    expect(page).to have_css(".sidebar-no-results")

    no_results_description = page.find(".sidebar-no-results__description")
    expect(no_results_description.text).to eq(
      "We couldn’t find anything matching ‘ieeee’.\n\nTry searching the entire admin interface.",
    )
  end

  it "temporarily expands section when filter" do
    visit("/admin")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.map(&:text)).to eq(
      [
        I18n.t("admin_js.admin.dashboard.title"),
        I18n.t("admin_js.admin.config.users.title"),
        I18n.t("admin_js.admin.config.search_everything.title"),
        I18n.t("admin_js.admin.config.groups.title"),
        I18n.t("admin_js.admin.config.site_settings.title"),
        I18n.t("admin_js.admin.config.whats_new.title"),
      ],
    )

    filter.filter("ie")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.map(&:text)).to eq(
      [
        I18n.t("admin_js.admin.config.content.title"),
        I18n.t("admin_js.admin.config.user_fields.title"),
        I18n.t("admin_js.admin.config.flags.title"),
        I18n.t("admin_js.admin.config.email.title"),
      ],
    )

    filter.filter("")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.map(&:text)).to eq(
      [
        I18n.t("admin_js.admin.dashboard.title"),
        I18n.t("admin_js.admin.config.users.title"),
        I18n.t("admin_js.admin.config.search_everything.title"),
        I18n.t("admin_js.admin.config.groups.title"),
        I18n.t("admin_js.admin.config.site_settings.title"),
        I18n.t("admin_js.admin.config.whats_new.title"),
      ],
    )
  end

  it "allows sections to be expanded" do
    visit("/admin")
    sidebar.toggle_all_sections
    expect(page).to have_selector(
      ".sidebar-section-link-content-text",
      minimum: UNFILTERED_LINK_COUNT,
    )

    sidebar.toggle_all_sections
    expect(page).to have_selector(".sidebar-section-link-content-text", count: 6)
    expect(all(".sidebar-section-link-content-text").map(&:text)).to eq(
      [
        I18n.t("admin_js.admin.dashboard.title"),
        I18n.t("admin_js.admin.config.users.title"),
        I18n.t("admin_js.admin.config.search_everything.title"),
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

  it "accepts hidden keywords like installed plugin names for filter" do
    Discourse.instance_variable_set(
      "@plugins",
      Plugin::Instance.find_all("#{Rails.root}/spec/fixtures/plugins"),
    )

    visit("/admin")
    sidebar.toggle_all_sections
    filter.filter("csp_extension")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.count).to eq(1)
    expect(links.map(&:text)).to eq([I18n.t("admin_js.admin.config.plugins.title")])
  end

  it "accepts components and themes keywords for filter" do
    Fabricate(:theme, name: "Air theme", component: false)
    Fabricate(:theme, name: "Kanban", component: true)

    visit("/admin")
    sidebar.toggle_all_sections

    filter.filter("air")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.count).to eq(1)
    expect(links.map(&:text)).to eq(["Themes and components"])

    filter.filter("kanban")
    links = page.all(".sidebar-section-link-content-text")
    expect(links.count).to eq(1)
    expect(links.map(&:text)).to eq(["Themes and components"])
  end

  it "highlights the 'Themes and components' link when the themes page is visited" do
    visit("/admin/customize/themes")
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
        I18n.t("admin_js.admin.config.search_everything.title"),
        I18n.t("admin_js.admin.config.groups.title"),
        I18n.t("admin_js.admin.config.whats_new.title"),
        I18n.t("admin_js.admin.config.reports.title"),
        I18n.t("admin_js.admin.config.watched_words.title"),
        I18n.t("admin_js.admin.config.staff_action_logs.title"),
      ],
    )
  end
end
