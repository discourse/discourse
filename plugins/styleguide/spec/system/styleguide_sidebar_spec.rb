# frozen_string_literal: true

RSpec.describe "Styleguide sidebar panel" do
  include ThemeScreenshotMarker

  fab!(:admin)

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:filter) { PageObjects::Components::Filter.new }

  before do
    SiteSetting.styleguide_enabled = true
    SiteSetting.navigation_menu = "sidebar"
    sign_in(admin)
  end

  it "replaces the forum sidebar with the styleguide's own navigation" do
    visit "/styleguide/atoms/buttons"

    expect(sidebar).to be_visible
    expect(page).to have_css(".sidebar-sections.styleguide-panel")

    %w[syntax atoms molecules organisms].each do |category|
      expect(sidebar).to have_section("styleguide__#{category}")
    end

    # The forum's own sections are displaced rather than merely pushed down.
    expect(sidebar).to have_no_section("categories")

    screenshot_marker(label: "styleguide-sidebar", only: :desktop)
  end

  it "links to a section without leaking a group query param" do
    visit "/styleguide"

    link = page.find(".sidebar-section-link[data-link-name='styleguide___buttons']")
    expect(link[:href]).to end_with("/styleguide/atoms/buttons")
  end

  it "marks the current section's link as active" do
    visit "/styleguide/atoms/buttons"

    expect(page).to have_css(".sidebar-section-link[data-link-name='styleguide___buttons'].active")
  end

  it "hands the sidebar back when leaving the styleguide" do
    visit "/styleguide/atoms/buttons"
    expect(sidebar).to have_no_section("categories")

    sidebar.click_back_to_forum

    expect(sidebar).to have_section("categories")
    expect(page).to have_no_css(".sidebar-sections.styleguide-panel")
  end

  it "does not offer a switch button for the panel" do
    visit "/styleguide"

    expect(sidebar).to have_no_switch_button("styleguide")
  end

  # The styleguide's nav used to render unconditionally, so a reader who prefers the header
  # dropdown must not lose it now that it lives in the sidebar.
  it "renders for a reader whose navigation menu preference is the header dropdown" do
    SiteSetting.navigation_menu = NavigationMenuSiteSetting::HEADER_DROPDOWN

    visit "/styleguide/atoms/buttons"

    expect(page).to have_css(".sidebar-sections.styleguide-panel")
  end

  it "filters the sections" do
    visit "/styleguide"

    filter.filter("typography")

    expect(page).to have_css(".sidebar-section-link[data-link-name='styleguide___typography']")
    expect(page).to have_no_css(".sidebar-section-link[data-link-name='styleguide___buttons']")
  end
end
