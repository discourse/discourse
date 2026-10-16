# frozen_string_literal: true

describe "Admin Site Setting Category Bulk Action" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  fab!(:admin)

  before { sign_in(admin) }

  it "prompts about unsaved settings when navigating away" do
    browser_page
      .goto("/admin/config/notifications")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    settings_page.fill_setting("max_mentions_per_post", 2)

    expect(banner).to RSpecPredicates.be_visible
    expect(banner.element).to contain_text(
      browser_text_pattern("You have 1 unsaved change"),
      useInnerText: true,
    )

    settings_page
      .locator(".admin-sidebar-nav-link")
      .filter(visible: true)
      .filter(hasText: browser_text_pattern("Login & authentication"))
      .click

    expect(browser_page).to have_url("/admin/config/notifications")

    expect(dialog).to be_open
    expect(dialog).to have_displayed_content("You have 1 unsaved change")

    dialog.click_no

    expect(browser_page).to have_url("/admin/config/login-and-authentication")
  end
end
