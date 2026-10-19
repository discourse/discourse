# frozen_string_literal: true

describe "Search menu hashtag autocomplete" do
  let(:search_page) { PageObjects::Pages::Search.new }

  fab!(:user)
  fab!(:category) { Fabricate(:category, name: "UX", slug: "ux") }
  fab!(:tag) { Fabricate(:tag, name: "design") }

  before do
    SiteSetting.tagging_enabled = true
    Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
    sign_in(user)
  end

  it "preserves prior hashtag when selecting a suggestion for a second hashtag" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    search_page.click_search_icon
    search_page.type_in_search_menu("#ux #des")

    expect(
      browser_root.locator(".search-menu-assistant-item.tag").filter(visible: true),
    ).not_to have_count(0)
    browser_root.locator(".search-menu-assistant-item.tag").filter(visible: true).first.click

    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator(
            "[id=#{"icon-search-input".to_s.to_json}], [name=#{"icon-search-input".to_s.to_json}]",
          ).or(browser_root.get_by_label("icon-search-input", exact: true)),
        )
        .filter(visible: true),
    ).to have_value("#ux #design")
  end
end
