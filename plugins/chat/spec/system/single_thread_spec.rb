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

  context "when threading is disabled for the channel" do
    fab!(:channel) { Fabricate(:chat_channel) }

    before { channel.update!(threading_enabled: false) }

    it "does not open the side panel for a single thread" do
      thread =
        chat_thread_chain_bootstrap(channel: channel, users: [current_user, Fabricate(:user)])
      chat_page.visit_channel(channel)
      channel_page.hover_message(thread.original_message)
      expect(page).not_to have_css(".chat-message-thread-btn")
    end
  end

  context "when threading is enabled for the channel" do
    fab!(:user_2) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread) { chat_thread_chain_bootstrap(channel: channel, users: [current_user, user_2]) }

    context "when returning to a thread where last read is not last message" do
      it "scrolls to the correct last read message" do
        message_1 = Fabricate(:chat_message, thread: thread, chat_channel: channel)
        thread.membership_for(current_user).update!(last_read_message: message_1)
        messages = Fabricate.times(50, :chat_message, thread: thread, chat_channel: channel)
        chat_page.visit_thread(thread)

        expect(page).to have_css("[data-id='#{message_1.id}'].-highlighted")
      end
    end

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

    context "when thread is forced and threading disabled" do
      before do
        channel.update!(threading_enabled: false)
        thread.update!(force: true)
      end

      it "doesn’t show back button " do
        chat_page.visit_thread(thread)

        expect(page).to have_no_css(".c-routes.--channel-thread .c-navbar__back-button")
      end
    end

    context "when in drawer" do
      it "opens the channel and highlights the message when clicking original message link" do
        visit("/latest")
        chat_page.open_from_header
        chat_drawer_page.open_channel(channel)
        channel_page.message_thread_indicator(thread.original_message).click
        find(".chat-message-info__original-message").click

        expect(chat_drawer_page).to have_open_channel(channel)
        expect(channel_page.messages).to have_message(
          id: thread.original_message.id,
          highlighted: true,
        )
      end
    end

    it "highlights the message in the channel when clicking original message link" do
      chat_page.visit_thread(thread)

      find(".chat-message-info__original-message").click

      expect(channel_page.messages).to have_message(
        id: thread.original_message.id,
        highlighted: true,
      )
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
        expect(thread_page.messages).to have_message(
          thread_id: thread.id,
          text: "new thread message",
        )
        thread_message = thread.last_message
        expect(thread_message.chat_channel_id).to eq(channel.id)
        expect(thread_message.thread.channel_id).to eq(channel.id)
      end

      it "does not echo the message in the channel pane" do
        chat_page.visit_channel(channel)
        channel_page.message_thread_indicator(thread.original_message).click
        expect(side_panel).to have_open_thread(thread)
        thread_page.send_message("new thread message")
        expect(thread_page.messages).to have_message(
          thread_id: thread.id,
          text: "new thread message",
        )
        thread_message = thread.reload.replies.last
        expect(channel_page).not_to have_css(channel_page.message_by_id_selector(thread_message.id))
      end

      it "changes the tracking bell to be Tracking level in the thread panel" do
        new_thread = Fabricate(:chat_thread, channel: channel, with_replies: 1, use_service: true)
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

        expect(thread_page.messages).to have_message(
          thread_id: thread.id,
          text: "the other user message",
        )

        using_session(:tab_1) do
          expect(side_panel).to have_open_thread(thread)
          expect(thread_page.messages).to have_message(
            thread_id: thread.id,
            text: "the other user message",
          )

          thread_page.send_message("this is a test message")

          expect(thread_page.messages).to have_message(
            thread_id: thread.id,
            text: "this is a test message",
          )
        end

        expect(thread_page.messages).to have_message(
          thread_id: thread.id,
          text: "this is a test message",
        )
      end

      it "does not mark the channel unread if another user sends a message in the thread" do
        other_user = Fabricate(:user)
        chat_system_user_bootstrap(user: other_user, channel: channel)
        Fabricate(
          :chat_message,
          thread: thread,
          user: other_user,
          message: "Hello world!",
          use_service: true,
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

      it "navigates back to channel when clicking original message link", mobile: true do
        chat_page.visit_thread(thread)

        find(".chat-message-info__original-message").click

        expect(page).to have_current_path("/chat/c/#{channel.slug}/#{channel.id}")
      end
    end

    context "when messages are separated by a day" do
      before do
        Fabricate(:chat_message, chat_channel: channel, thread: thread, created_at: 2.days.ago)
      end

      it "shows a date separator" do
        chat_page.visit_thread(thread)

        expect(page).to have_selector(".chat-thread .chat-message-separator__text", text: "Today")
      end
    end
  end
end
