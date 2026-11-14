# frozen_string_literal: true

describe "Wireframe welcome banner block" do
  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }

  before do
    SiteSetting.wireframe_enabled = true
    SiteSetting.has_login_hint = false
    Fabricate(
      :theme_site_setting_with_service,
      theme: Theme.find_default,
      name: "wireframe_custom_homepage",
      value: true,
    )
    sign_in(admin)
  end

  it "replaces the site's welcome banner on every page once a template places it" do
    visit("/latest")
    expect(page).to have_css(".welcome-banner")

    visit("/")
    find(".wireframe-empty-homepage__add").click
    editor.add_block_to_empty_outlet("welcome-banner")

    expect(page).to have_css(".d-block-welcome-banner .welcome-banner__search-menu")
    expect(page).to have_no_css(".welcome-banner")

    editor.publish
    expect(editor).to have_reader

    visit("/latest")
    expect(page).to have_css("#main-outlet")
    expect(page).to have_no_css(".welcome-banner")
  end
end
