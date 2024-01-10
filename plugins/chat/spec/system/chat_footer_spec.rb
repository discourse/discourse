# frozen_string_literal: true

RSpec.describe "Chat footer on mobile", type: :system, mobile: true do
  fab!(:user)
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: user) }
  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    sign_in(user)
    channel.add(user)
  end

  context "with multiple tabs" do
    it "shows footer" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".c-footer")
      expect(page).to have_css(".c-footer__item", count: 2)
      expect(page).to have_css("#chat-footer-direct-messages")
      expect(page).to have_css("#chat-footer-channels")
    end

    it "hides footer when channel is open" do
      chat_page.visit_channel(channel)

      expect(page).to have_no_css(".c-footer")
    end

    it "redirects the user to the direct messages tab" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_current_path("/chat/direct-messages")
    end

    it "shows threads tab when user has threads" do
      thread = Fabricate(:chat_thread, channel: channel, original_message: message)
      Fabricate(:chat_message, chat_channel: channel, thread: thread)
      thread.update!(replies_count: 1)

      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".c-footer")
      expect(page).to have_css("#chat-footer-threads")
    end
  end

  context "with only 1 tab" do
    before do
      SiteSetting.direct_message_enabled_groups = "3" # staff only
    end

    it "does not render footer" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_no_css(".c-footer")
    end

    it "redirects user to channels page" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_current_path("/chat/channels")
    end
  end
end
