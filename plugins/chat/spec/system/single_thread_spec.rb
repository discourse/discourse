# frozen_string_literal: true

describe "Single thread in side panel", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:open_thread) { PageObjects::Pages::ChatThread.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }

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

    it "opens the single thread in the drawer using the indicator" do
      visit("/latest")
      chat_page.open_from_header
      chat_drawer_page.open_channel(channel)
      channel_page.message_thread_indicator(thread.original_message).click
      expect(chat_drawer_page).to have_open_thread(thread)
    end

    it "navigates back to the channel when clicking back button from a thread" do
      visit("/latest")
      chat_page.open_from_header
      chat_drawer_page.open_channel(channel)
      channel_page.message_thread_indicator(thread.original_message).click
      expect(chat_drawer_page).to have_open_thread(thread)

      chat_drawer_page.back

      expect(chat_drawer_page).to have_open_channel(channel)
    end

    it "opens the side panel for a single thread from the indicator" do
      chat_page.visit_channel(channel)
      channel_page.message_thread_indicator(thread.original_message).click
      expect(side_panel).to have_open_thread(thread)
    end

    xit "shows the excerpt of the thread original message" do
      chat_page.visit_channel(channel)
      channel_page.message_thread_indicator(thread.original_message).click
      expect(open_thread).to have_header_content(thread.excerpt)
    end

    xit "shows the avatar and username of the original message user" do
      chat_page.visit_channel(channel)
      channel_page.message_thread_indicator(thread.original_message).click
      expect(open_thread.omu).to have_css(".chat-user-avatar img.avatar")
      expect(open_thread.omu).to have_content(thread.original_message_user.username)
    end

    context "when using mobile" do
      it "opens the side panel for a single thread using the indicator", mobile: true do
        chat_page.visit_channel(channel)
        channel_page.message_thread_indicator(thread.original_message).click
        expect(side_panel).to have_open_thread(thread)
      end
    end
  end
end
