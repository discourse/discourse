# frozen_string_literal: true

describe "Thread indicator for chat messages", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

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

    it "shows no thread indicators in the channel" do
      thread = chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
      chat_page.visit_channel(channel)
      expect(channel_page).not_to have_thread_indicator(thread.original_message)
    end
  end

  context "when threading_enabled is false for the channel" do
    fab!(:channel) { Fabricate(:chat_channel) }
    before do
      SiteSetting.enable_experimental_chat_threaded_discussions = true
      channel.update!(threading_enabled: false)
    end

    it "shows no thread inidcators in the channel" do
      thread = chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
      chat_page.visit_channel(channel)
      expect(channel_page).not_to have_thread_indicator(thread.original_message)
    end
  end

  context "when enable_experimental_chat_threaded_discussions is true and threading is enabled for the channel" do
    fab!(:channel) { Fabricate(:chat_channel) }
    fab!(:thread_1) do
      chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
    end
    fab!(:thread_2) do
      chat_thread_chain_bootstrap(
        channel: channel,
        users: [current_user, other_user],
        messages_count: 2,
      )
    end

    before do
      SiteSetting.enable_experimental_chat_threaded_discussions = true
      channel.update!(threading_enabled: true)
    end

    it "throws thread indicators on all original messages" do
      chat_page.visit_channel(channel)
      expect(channel_page).to have_thread_indicator(thread_1.original_message)
      expect(channel_page).to have_thread_indicator(thread_2.original_message)
    end

    it "shows the correct reply counts" do
      chat_page.visit_channel(channel)
      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_css(
        ".chat-message-thread-indicator__replies-count",
        text: I18n.t("js.chat.thread.replies", count: 3),
      )
      expect(channel_page.message_thread_indicator(thread_2.original_message)).to have_css(
        ".chat-message-thread-indicator__replies-count",
        text: I18n.t("js.chat.thread.replies", count: 1),
      )
    end

    it "clicking a thread indicator opens the thread panel" do
      chat_page.visit_channel(channel)
      channel_page.message_thread_indicator(thread_1.original_message).click
      expect(side_panel).to have_open_thread(thread_1)
    end

    it "shows the thread indicator and hides the sent message when a user first replies to a message without a thread" do
      message_without_thread = Fabricate(:chat_message, chat_channel: channel, user: other_user)
      chat_page.visit_channel(channel)
      channel_page.reply_to(message_without_thread)
      channel_page.fill_composer("this is a reply to make a new thread")
      channel_page.click_send_message

      expect(channel_page).to have_thread_indicator(message_without_thread)

      new_thread = nil
      try_until_success(timeout: 5) do
        new_thread = message_without_thread.reload.thread
        expect(new_thread).to be_present
      end

      expect(page).not_to have_css(channel_page.message_by_id_selector(new_thread.replies.first))
    end

    it "increments the indicator when a new reply is sent in the thread" do
      chat_page.visit_channel(channel)
      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_css(
        ".chat-message-thread-indicator__replies-count",
        text: I18n.t("js.chat.thread.replies", count: 3),
      )
      channel_page.message_thread_indicator(thread_1.original_message).click
      expect(side_panel).to have_open_thread(thread_1)
      open_thread.send_message(thread_1.id, "new thread message")
      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_css(
        ".chat-message-thread-indicator__replies-count",
        text: I18n.t("js.chat.thread.replies", count: 4),
      )
    end
  end
end
