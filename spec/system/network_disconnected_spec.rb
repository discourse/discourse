# frozen_string_literal: true

RSpec.describe "Network Disconnected", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  it "Message bus connectivity service adds class to DOM and displays offline indicator" do
    sign_in(current_user)
    visit("/c")

    expect(page).to have_no_css("html.message-bus-offline")
    expect(page).to have_no_css(".offline-indicator")

    page.driver.browser.network_conditions = { offline: true, latency: 0, throughput: 0 }

    # Message bus connectivity services adds the disconnected class to the DOM
    expect(page).to have_css("html.message-bus-offline")

    # Offline indicator is rendered
    expect(page).to have_css(".offline-indicator")
  end
end
