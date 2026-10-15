# frozen_string_literal: true

describe "bootstrap_error_pages" do
  before { SiteSetting.bootstrap_error_pages = true }

  it "boots ember for non-existent route" do
    browser_page.goto("/foobar").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator("#site-logo").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("div.page-not-found").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("body.no-ember").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end

  it "boots ember for non-existent topic" do
    browser_page.goto("/t/999999999999").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator("#site-logo").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("div.page-not-found").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("body.no-ember").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
  end
end
