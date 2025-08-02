# frozen_string_literal: true

describe "Interface color selector", type: :system do
  let!(:light_scheme) { ColorScheme.find_by(base_scheme_id: "Solarized Light") }
  let!(:dark_scheme) { ColorScheme.find_by(base_scheme_id: "Dark") }

  let(:selector_in_sidebar) do
    PageObjects::Components::InterfaceColorSelector.new(".sidebar-footer-actions")
  end
  let(:selector_in_header) do
    PageObjects::Components::InterfaceColorSelector.new(".d-header-icons")
  end

  let(:interface_color_mode) { PageObjects::Components::InterfaceColorMode.new }

  let(:home_logo) { PageObjects::Components::HomeLogo.new }

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  fab!(:user)

  fab!(:dark_mode_image) { Fabricate(:image_upload, color: "white", width: 400, height: 120) }
  fab!(:light_mode_image) { Fabricate(:image_upload, color: "black", width: 400, height: 120) }

  fab!(:small_dark_mode_image) { Fabricate(:image_upload, color: "white", width: 120, height: 120) }
  fab!(:small_light_mode_image) do
    Fabricate(:image_upload, color: "black", width: 120, height: 120)
  end

  fab!(:category) do
    Fabricate(
      :category,
      uploaded_logo: small_light_mode_image,
      uploaded_logo_dark: small_dark_mode_image,
      uploaded_background: light_mode_image,
      uploaded_background_dark: dark_mode_image,
    )
  end

  before do
    SiteSetting.interface_color_selector = "sidebar_footer"
    SiteSetting.default_dark_mode_color_scheme_id = dark_scheme.id

    SiteSetting.logo = light_mode_image
    SiteSetting.logo_dark = dark_mode_image
  end

  it "is not available when there's no default dark scheme" do
    SiteSetting.default_dark_mode_color_scheme_id = -1

    visit("/")

    expect(selector_in_sidebar).to be_not_available
  end

  it "is not available when the default theme's scheme is the same as the site's default dark scheme" do
    Theme.find(SiteSetting.default_theme_id).update!(color_scheme_id: dark_scheme.id)

    visit("/")

    expect(selector_in_sidebar).to be_not_available
  end

  it "is not available if the user uses the same scheme for dark mode as the light mode" do
    user.user_option.update!(color_scheme_id: light_scheme.id, dark_scheme_id: -1)
    sign_in(user)

    visit("/")

    expect(selector_in_sidebar).to be_not_available
  end

  it "can switch between light, dark and auto modes without requiring a full page refresh" do
    visit("/")

    selector_in_sidebar.expand
    selector_in_sidebar.light_option.click

    expect(interface_color_mode).to have_light_mode_forced
    expect(home_logo).to have_light_logo_forced

    selector_in_sidebar.expand
    selector_in_sidebar.dark_option.click

    expect(interface_color_mode).to have_dark_mode_forced
    expect(home_logo).to have_dark_logo_forced

    selector_in_sidebar.expand
    selector_in_sidebar.auto_option.click

    expect(interface_color_mode).to have_auto_color_mode
    expect(home_logo).to have_auto_color_mode
  end

  it "uses the right category logos when switching color modes" do
    visit("/")

    selector_in_sidebar.expand
    selector_in_sidebar.dark_option.click

    sidebar.click_section_link(category.name)

    expect(page).to have_css('.category-logo picture source[media="all"]', visible: false)

    styles = find("#d-styles", visible: false)["innerHTML"]
    expect(styles).to include(
      "body.category-#{category.slug} { background-image: url(#{dark_mode_image.url}); }",
    )

    selector_in_sidebar.expand
    selector_in_sidebar.light_option.click

    expect(page).to have_css('.category-logo picture source[media="none"]', visible: false)

    styles = find("#d-styles", visible: false)["innerHTML"]
    expect(styles).to include(
      "body.category-#{category.slug} { background-image: url(#{light_mode_image.url}); }",
    )

    selector_in_sidebar.expand
    selector_in_sidebar.auto_option.click

    expect(page).to have_css(
      '.category-logo picture source[media="(prefers-color-scheme: dark)"]',
      visible: false,
    )

    styles = find("#d-styles", visible: false)["innerHTML"]
    expect(styles).to include(
      "body.category-#{category.slug} { background-image: url(#{light_mode_image.url}); }",
    )
    expect(styles).to include(<<~CSS)
      @media (prefers-color-scheme: dark) {
      body.category-#{category.slug} { background-image: url(#{dark_mode_image.url}); }
      }
    CSS
  end

  it "maintains the user's preference across page refreshes" do
    visit("/")

    selector_in_sidebar.expand
    selector_in_sidebar.dark_option.click

    expect(interface_color_mode).to have_dark_mode_forced

    visit(category.url)

    expect(interface_color_mode).to have_dark_mode_forced

    expect(page).to have_css('.category-logo picture source[media="all"]', visible: false)

    styles = find("#d-styles", visible: false)["innerHTML"]
    expect(styles).to include(
      "body.category-#{category.slug} { background-image: url(#{dark_mode_image.url}); }",
    )
  end

  it "can be configured to appear in the header instead of the sidebar footer" do
    SiteSetting.interface_color_selector = "header"

    visit("/")

    expect(selector_in_sidebar).to be_not_available
    expect(selector_in_header).to be_available
  end
end
