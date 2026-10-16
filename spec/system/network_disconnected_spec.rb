# frozen_string_literal: true

RSpec.describe "Network Disconnected" do
  let(:cdp) { PageObjects::CDP.new }

  it "NetworkConnectivity service adds class to DOM and displays offline indicator" do
    SiteSetting.enable_offline_indicator = true

    browser_page.goto("/c").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(".d-header").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("html.network-disconnected").filter(visible: true)).to have_count(0)
    expect(browser_root.locator(".offline-indicator").filter(visible: true)).to have_count(0)

    cdp.with_network_disconnected do
      expect(
        browser_root.locator("html.network-disconnected").filter(visible: true),
      ).not_to have_count(0)
      expect(browser_root.locator(".offline-indicator").filter(visible: true)).not_to have_count(0)
    end
  end
end
