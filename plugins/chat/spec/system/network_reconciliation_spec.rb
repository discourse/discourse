# frozen_string_literal: true

RSpec.describe "Network reconciliation", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    channel_1.add(other_user)
  end

  context "when user recovers network" do
    it "recovers state" do
      using_session(:disconnected_current_user) do
        sign_in(current_user)
        visit("/")
        page.driver.browser.network_conditions = { offline: true, latency: 0, throughput: 0 }
      end

      using_session(:other_user) do |session|
        sign_in(other_user)
        chat_page.visit_channel(channel_1)
        chat_channel_page.send_message("hello @#{current_user.username}!")
        session.quit
      end

      using_session(:connected_current_user) do |session|
        sign_in(current_user)
        visit("/")
        expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator")
        chat_page.visit_channel(channel_1)
        expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
        session.quit
      end

      using_session(:disconnected_current_user) do |session|
        expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
        page.driver.browser.network_conditions = { offline: false, latency: 0, throughput: 0 }
        expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")

        # generally speaking sleep should be avoided in tests, but in this case
        # we need to wait for the client to reconnect and receive the message
        # right at the start the icon won't be there so checking for not will be true
        # and checking for present could also be true as it might be within capybara finder delay
        # which is what we are testing here and want to avoid
        sleep 1

        expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
        session.quit
      end
    end
  end
end
