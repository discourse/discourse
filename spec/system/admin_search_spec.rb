# frozen_string_literal: true

describe "Admin Search" do
  fab!(:current_user, :admin)
  let(:search_modal) { PageObjects::Modals::AdminSearch.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(current_user) }

  it "can search for settings, pages, themes, components, and reports" do
    Fabricate(:theme, name: "Discourse Invincible Theme")
    Fabricate(:theme, name: "Discourse Redacted", component: true)

    Theme
      .any_instance
      .stubs(:internal_translations)
      .returns([stub(key: "theme_metadata.description", value: "Some description")])

    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.click_search_input

    search_modal.search("min_topic_title")
    expect(search_modal.find_result("setting", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Min topic title length"),
      useInnerText: true,
    )
    expect(search_modal.find_result("setting", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern(I18n.t("site_settings.min_topic_title_length")),
      useInnerText: true,
    )

    search_modal.search("mau")
    expect(search_modal.find_result("report", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern(I18n.t("reports.dau_by_mau.title")),
      useInnerText: true,
    )
    expect(search_modal.find_result("report", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern(I18n.t("reports.dau_by_mau.description")),
      useInnerText: true,
    )

    search_modal.search("permalinks")
    expect(search_modal.find_result("page", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern(I18n.t("admin_js.admin.config.permalinks.title")),
      useInnerText: true,
    )
    expect(search_modal.find_result("page", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern(I18n.t("admin_js.admin.config.permalinks.header_description")),
      useInnerText: true,
    )

    search_modal.search("invincible")
    expect(search_modal.find_result("theme", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Discourse Invincible Theme"),
      useInnerText: true,
    )
    expect(search_modal.find_result("theme", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Some description"),
      useInnerText: true,
    )

    search_modal.search("redacted")
    expect(search_modal.find_result("component", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Discourse Redacted"),
      useInnerText: true,
    )
    expect(search_modal.find_result("component", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Some description"),
      useInnerText: true,
    )
  end

  it "can search full page" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.click_search_input
    search_modal.search("min_topic_title")
    search_modal.input_enter
    expect(browser_page).to PlaywrightMatchers.have_url("/admin/search?filter=min_topic_title")
    expect(search_modal.find_result("setting", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern("Min topic title length"),
      useInnerText: true,
    )
    expect(search_modal.find_result("setting", 0)).to PlaywrightMatchers.contain_text(
      browser_text_pattern(I18n.t("site_settings.min_topic_title_length")),
      useInnerText: true,
    )
  end

  it "informs user about no results" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.click_search_input

    search_modal.search("very long search phrase")

    expect(search_modal).to have_displayed_content(
      'We couldn’t find anything matching "very long search phrase".',
    )
  end

  it "opens search modal with keyboard shortcut" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator("#site-logo").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "/"].join("+"),
    )
    expect(search_modal).to be_open
  end

  it "works with sections which have a redirect instead of explicit /settings route" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar.click_search_input

    search_modal.search("tags tag style")
    search_modal.find_result("setting", 0).click

    expect(browser_page).to PlaywrightMatchers.have_url("/admin/config/content?filter=tag_style")
  end

  it "works for social logins" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.click_search_input
    search_modal.search("google oauth2 logins")
    search_modal.find_result("setting", 0).click

    expect(browser_page).to PlaywrightMatchers.have_url(
      "/admin/config/login-and-authentication/authenticators?filter=enable_google_oauth2_logins",
    )
  end

  it "works for discourse connect" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    sidebar.click_search_input
    search_modal.search("enable discourse connect")
    search_modal.find_result("setting", 0).click

    expect(browser_page).to PlaywrightMatchers.have_url(
      "/admin/config/login-and-authentication/discourseconnect?filter=enable_discourse_connect",
    )
  end
end
