# frozen_string_literal: true

describe "Powered by Discourse" do
  it "appears when enabled" do
    SiteSetting.enable_powered_by_discourse = true

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(".powered-by-discourse").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "does not appear on admin routes when enabled" do
    SiteSetting.enable_powered_by_discourse = true

    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(".powered-by-discourse").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "does not appear on login required route when enabled" do
    SiteSetting.enable_powered_by_discourse = true
    SiteSetting.login_required = true

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(".powered-by-discourse").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "does not appear when disabled" do
    SiteSetting.enable_powered_by_discourse = false

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(".powered-by-discourse").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end
end
