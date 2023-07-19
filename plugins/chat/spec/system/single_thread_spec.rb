# frozen_string_literal: true

describe "Single thread in side panel", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }

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

    context "when in full page" do
      context "when switching channel" do
        fab!(:channel_2) { Fabricate(:chat_channel, threading_enabled: true) }

        before { channel_2.add(current_user) }

        it "closes the opened thread" do
          chat_page.visit_thread(thread)
          expect(side_panel).to have_open_thread(thread)

          sidebar_page.open_channel(channel_2)

          expect(side_panel).to have_no_open_thread
        end
      end

      context "when closing the thread" do
        it "closes it" do
          chat_page.visit_thread(thread)
          expect(side_panel).to have_open_thread(thread)

          thread_page.close

          expect(side_panel).to have_no_open_thread
        end
      end
    end

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

    describe "sending a message" do
      it "shows the message in the thread pane and links it to the correct channel" do
        chat_page.visit_channel(channel)
        channel_page.message_thread_indicator(thread.original_message).click
        expect(side_panel).to have_open_thread(thread)
        thread_page.send_message("new thread message")
        expect(thread_page).to have_message(thread_id: thread.id, text: "new thread message")
        thread_message = thread.last_message
        expect(thread_message.chat_channel_id).to eq(channel.id)
        expect(thread_message.thread.channel_id).to eq(channel.id)
      end

      it "does not echo the message in the channel pane" do
        chat_page.visit_channel(channel)
        channel_page.message_thread_indicator(thread.original_message).click
        expect(side_panel).to have_open_thread(thread)
        thread_page.send_message("new thread message")
        expect(thread_page).to have_message(thread_id: thread.id, text: "new thread message")
        thread_message = thread.reload.replies.last
        expect(channel_page).not_to have_css(channel_page.message_by_id_selector(thread_message.id))
      end

      it "changes the tracking bell to be Tracking level in the thread panel" do
        new_thread = Fabricate(:chat_thread, channel: channel, with_replies: 1)
        chat_page.visit_channel(channel)
        channel_page.message_thread_indicator(new_thread.original_message).click
        expect(side_panel).to have_open_thread(new_thread)
        expect(thread_page).to have_notification_level("normal")
        thread_page.send_message("new thread message")
        expect(thread_page).to have_notification_level("tracking")
      end

      it "handles updates from multiple users sending messages in the thread" do
        using_session(:tab_1) do
          sign_in(current_user)
          chat_page.visit_channel(channel)
          channel_page.message_thread_indicator(thread.original_message).click
        end

        other_user = Fabricate(:user)
        chat_system_user_bootstrap(user: other_user, channel: channel)
        sign_in(other_user)
        chat_page.visit_channel(channel)
        channel_page.message_thread_indicator(thread.original_message).click

        expect(side_panel).to have_open_thread(thread)

        thread_page.send_message("the other user message")

        expect(thread_page).to have_message(thread_id: thread.id, text: "the other user message")

        using_session(:tab_1) do
          expect(side_panel).to have_open_thread(thread)
          expect(thread_page).to have_message(thread_id: thread.id, text: "the other user message")

          thread_page.send_message("this is a test message")

          expect(thread_page).to have_message(thread_id: thread.id, text: "this is a test message")
        end

        expect(thread_page).to have_message(thread_id: thread.id, text: "this is a test message")
      end

      it "does not mark the channel unread if another user sends a message in the thread" do
        other_user = Fabricate(:user)
        chat_system_user_bootstrap(user: other_user, channel: channel)
        Chat::MessageCreator.create(
          chat_channel: channel,
          user: other_user,
          content: "Hello world!",
          thread_id: thread.id,
        )
        sign_in(current_user)
        chat_page.visit_channel(channel)
        expect(page).not_to have_css(
          ".sidebar-section-link.channel-#{channel.id} .sidebar-section-link-suffix.unread",
        )
      end
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
