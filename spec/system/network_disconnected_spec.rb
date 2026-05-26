# frozen_string_literal: true

RSpec.describe "Network Disconnected" do
  let(:cdp) { PageObjects::CDP.new }

  it "NetworkConnectivity service adds class to DOM and displays offline indicator" do
    SiteSetting.enable_offline_indicator = true

    visit("/c")

    expect(page).to have_css(".d-header")
    expect(page).to have_no_css("html.network-disconnected")
    expect(page).to have_no_css(".offline-indicator")

    cdp.with_network_disconnected do
      expect(page).to have_css("html.network-disconnected")
      expect(page).to have_css(".offline-indicator")
    end
  end
end
