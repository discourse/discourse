# frozen_string_literal: true

describe "Single thread in side panel", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:open_thread) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap(current_user, [channel])
    sign_in(current_user)
  end

  context "when enable_experimental_chat_threaded_discussions is disabled" do
    fab!(:channel) { Fabricate(:chat_channel) }
    before { SiteSetting.enable_experimental_chat_threaded_discussions = false }

    it "does not open the side panel for a single thread" do
      thread =
        chat_thread_chain_bootstrap(channel: channel, users: [current_user, Fabricate(:user)])
      chat_page.visit_channel(channel)
      channel_page.hover_message(thread.original_message)
      expect(page).not_to have_css(".chat-message-thread-btn")
    end
  end

  context "when threading_enabled is false for the channel" do
    fab!(:channel) { Fabricate(:chat_channel) }
    before do
      SiteSetting.enable_experimental_chat_threaded_discussions = true
      channel.update!(threading_enabled: false)
    end

    it "does not open the side panel for a single thread" do
      thread =
        chat_thread_chain_bootstrap(channel: channel, users: [current_user, Fabricate(:user)])
      chat_page.visit_channel(channel)
      channel_page.hover_message(thread.original_message)
      expect(page).not_to have_css(".chat-message-thread-btn")
    end
  end

  context "when enable_experimental_chat_threaded_discussions is true and threading is enabled for the channel" do
    fab!(:user_2) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread) { chat_thread_chain_bootstrap(channel: channel, users: [current_user, user_2]) }

    before { SiteSetting.enable_experimental_chat_threaded_discussions = true }

    it "opens the side panel for a single thread from the message actions menu" do
      chat_page.visit_channel(channel)
      channel_page.open_message_thread(thread.original_message)
      expect(side_panel).to have_open_thread(thread)
    end

    it "shows the excerpt of the thread original message" do
      chat_page.visit_channel(channel)
      channel_page.open_message_thread(thread.original_message)
      expect(open_thread).to have_header_content(thread.excerpt)
    end

    it "shows the avatar and username of the original message user" do
      chat_page.visit_channel(channel)
      channel_page.open_message_thread(thread.original_message)
      expect(open_thread.op).to have_css(".chat-user-avatar img.avatar")
      expect(open_thread.op).to have_content(thread.original_message_user.username)
    end

    context "when using mobile" do
      it "opens the side panel for a single thread from the mobile message actions menu",
         mobile: true do
        chat_page.visit_channel(channel)
        channel_page.open_message_thread_mobile(thread.chat_messages.last)
        expect(side_panel).to have_open_thread(thread)
      end
    end
  end
end
