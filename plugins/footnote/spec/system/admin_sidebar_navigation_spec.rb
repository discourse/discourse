# frozen_string_literal: true

RSpec.describe "Admin | Sidebar Navigation" do
  fab!(:admin)

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  fab!(:navigation_menu) do
    Fabricate(:theme_site_setting_with_service, name: "navigation_menu", value: "sidebar")
  end

  before { sign_in(admin) }

  it "adds an auto-generated plugin link to the admin sidebar" do
    SiteSetting.enable_markdown_footnotes = true

    visit("/admin")

    sidebar.toggle_section(:plugins)

    expect(page).to have_css(
      ".sidebar-section-link-content-text",
      text: I18n.t("js.footnote.title"),
    )
  end
end
