# frozen_string_literal: true

RSpec.describe "Chat MessageBus | user-state events", type: :system do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:sidebar_page) { PageObjects::Pages::ChatSidebar.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap(current_user, [channel])
    channel.add(other_user)
  end

  describe "tracking_state" do
    it "shows unread indicator when another user sends a message" do
      sign_in(current_user)
      other_channel = Fabricate(:category_channel)
      other_channel.add(current_user)
      chat_page.visit_channel(other_channel)

      Fabricate(:chat_message, chat_channel: channel, user: other_user, use_service: true)

      expect(sidebar_page).to have_unread_channel(channel)
    end
  end

  describe "has_threads" do
    it "shows My Threads section when user gets their first thread" do
      sign_in(current_user)
      message =
        Fabricate(:chat_message, chat_channel: channel, user: current_user, use_service: true)

      other_channel = Fabricate(:category_channel)
      other_channel.add(current_user)
      chat_page.visit_channel(other_channel)

      expect(sidebar_page).to have_no_user_threads_section

      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: other_user,
        in_reply_to: message,
        use_service: true,
      )

      expect(sidebar_page).to have_user_threads_section
    end
  end
end
