# frozen_string_literal: true

RSpec.describe "Network Disconnected", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  before { skip(<<~TEXT) }
    This group of tests is flaky and needs to be fixed. Example of error:

    Failures:

     1) Network Disconnected Doesn't show the offline indicator when the site setting isn't present
     Failure/Error: expect(page).to have_css("html.message-bus-offline")
       expected to find css "html.message-bus-offline" but there were no matches
    TEXT

  def with_network_disconnected
    page.driver.browser.network_conditions = { offline: true }
    yield
    page.driver.browser.network_conditions = { offline: false }
  end

  it "Message bus connectivity service adds class to DOM and displays offline indicator" do
    SiteSetting.enable_offline_indicator = true

    visit("/c")

    expect(page).to have_no_css("html.message-bus-offline")
    expect(page).to have_no_css(".offline-indicator")

    with_network_disconnected do
      # Message bus connectivity services adds the disconnected class to the DOM
      expect(page).to have_css("html.message-bus-offline")

      # Offline indicator is rendered
      expect(page).to have_css(".offline-indicator")
    end
  end

  it "Doesn't show the offline indicator when the site setting isn't present" do
    SiteSetting.enable_offline_indicator = false

    visit("/c")

    with_network_disconnected do
      expect(page).to have_css("html.message-bus-offline")
      expect(page).not_to have_css(".offline-indicator")
    end
  end
end
