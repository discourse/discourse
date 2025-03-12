# frozen_string_literal: true

RSpec.describe "Admin | Sidebar Navigation", type: :system do
  fab!(:admin)

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before do
    SiteSetting.navigation_menu = "sidebar"

    sign_in(admin)
  end

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
