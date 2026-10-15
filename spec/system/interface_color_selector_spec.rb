# frozen_string_literal: true

describe "Interface color selector" do
  let!(:light_scheme) do
    ColorScheme.find_by(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Solarized Light"])
  end
  let!(:dark_scheme) { ColorScheme.find_by(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"]) }

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
    Theme.find_default.update!(dark_color_scheme_id: dark_scheme.id)

    SiteSetting.logo = light_mode_image
    SiteSetting.logo_dark = dark_mode_image
  end

  it "is not available when there's no default dark scheme" do
    Theme.find_default.update!(dark_color_scheme_id: nil)

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(selector_in_sidebar).to be_not_available
  end

  it "is not available when the default theme's scheme is the same as the site's default dark scheme" do
    Theme.find_default.update!(color_scheme_id: dark_scheme.id)

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(selector_in_sidebar).to be_not_available
  end

  it "is not available if the user uses the same scheme for dark mode as the light mode" do
    light_scheme.update!(user_selectable: true)
    user.user_option.update!(color_scheme_id: light_scheme.id, dark_scheme_id: light_scheme.id)
    sign_in(user)

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(selector_in_sidebar).to be_not_available
  end

  it "can switch between light, dark and auto modes without requiring a full page refresh" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    selector_in_sidebar.expand
    selector_in_sidebar.dark_option.click

    sidebar.click_section_link(category.name)

    expect(
      browser_root.locator('.category-logo picture source[media="all"]'),
    ).not_to PlaywrightMatchers.have_count(0)

    styles =
      browser_root.locator("#d-styles").evaluate(
        "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
        arg: "innerHTML",
      )
    expect(styles).to include(
      "body.category-#{category.slug} { background-image: url(#{dark_mode_image.url}); }",
    )

    selector_in_sidebar.expand
    selector_in_sidebar.light_option.click

    expect(
      browser_root.locator('.category-logo picture source[media="none"]'),
    ).not_to PlaywrightMatchers.have_count(0)

    styles =
      browser_root.locator("#d-styles").evaluate(
        "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
        arg: "innerHTML",
      )
    expect(styles).to include(
      "body.category-#{category.slug} { background-image: url(#{light_mode_image.url}); }",
    )

    selector_in_sidebar.expand
    selector_in_sidebar.auto_option.click

    expect(
      browser_root.locator('.category-logo picture source[media="(prefers-color-scheme: dark)"]'),
    ).not_to PlaywrightMatchers.have_count(0)

    styles =
      browser_root.locator("#d-styles").evaluate(
        "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
        arg: "innerHTML",
      )
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
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    selector_in_sidebar.expand
    selector_in_sidebar.dark_option.click

    expect(interface_color_mode).to have_dark_mode_forced

    browser_page.goto(category.url).tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(interface_color_mode).to have_dark_mode_forced

    expect(
      browser_root.locator('.category-logo picture source[media="all"]'),
    ).not_to PlaywrightMatchers.have_count(0)

    styles =
      browser_root.locator("#d-styles").evaluate(
        "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
        arg: "innerHTML",
      )
    expect(styles).to include(
      "body.category-#{category.slug} { background-image: url(#{dark_mode_image.url}); }",
    )
  end

  it "can be configured to appear in the header instead of the sidebar footer" do
    SiteSetting.interface_color_selector = "header"

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(selector_in_sidebar).to be_not_available
    expect(selector_in_header).to be_available
  end
end
