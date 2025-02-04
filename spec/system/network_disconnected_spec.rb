# frozen_string_literal: true

RSpec.describe "Network Disconnected", type: :system do
  let(:cdp) { PageObjects::CDP.new }

  it "NetworkConnectivity service adds class to DOM and displays offline indicator" do
    skip_on_ci!(<<~TEXT)
      In CI this test will randomly flake - timing issue with the offline indicator
      not being rendered soon enough after network conditions change
    TEXT

    SiteSetting.enable_offline_indicator = true

    visit("/c")

    expect(page).to have_no_css("html.network-disconnected")
    expect(page).to have_no_css(".offline-indicator")

    cdp.with_network_disconnected do
      # Message bus connectivity services adds the disconnected class to the DOM
      expect(page).to have_css("html.network-disconnected")

      # Offline indicator is rendered
      expect(page).to have_css(".offline-indicator")
    end
  end
end
