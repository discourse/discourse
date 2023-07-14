# frozen_string_literal: true

RSpec.describe "Network Disconnected", type: :system do
  def with_network_disconnected
    begin
      page.driver.browser.network_conditions = { offline: true }
      yield
    ensure
      page.driver.browser.network_conditions = { offline: false }
    end
  end

  it "NetworkConnectivity service adds class to DOM and displays offline indicator" do
    SiteSetting.enable_offline_indicator = true

    visit("/c")

    expect(page).to have_no_css("html.network-disconnected")
    expect(page).to have_no_css(".offline-indicator")

    with_network_disconnected do
      # Message bus connectivity services adds the disconnected class to the DOM
      expect(page).to have_css("html.network-disconnected")

      # Offline indicator is rendered
      expect(page).to have_css(".offline-indicator")
    end
  end
end
