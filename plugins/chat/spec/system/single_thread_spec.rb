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

    describe "sending a message" do
      it "shows the message in the thread pane and links it to the correct channel" do
        chat_page.visit_channel(channel)
        channel_page.message_thread_indicator(thread.original_message).click
        expect(side_panel).to have_open_thread(thread)
        open_thread.send_message(thread.id, "new thread message")
        expect(open_thread).to have_message(thread.id, text: "new thread message")
        thread_message = thread.replies.last
        expect(thread_message.chat_channel_id).to eq(channel.id)
        expect(thread_message.thread.channel_id).to eq(channel.id)
      end

      it "does not echo the message in the channel pane" do
        chat_page.visit_channel(channel)
        channel_page.message_thread_indicator(thread.original_message).click
        expect(side_panel).to have_open_thread(thread)
        open_thread.send_message(thread.id, "new thread message")
        expect(open_thread).to have_message(thread.id, text: "new thread message")
        expect(channel_page).not_to have_css(channel_page.message_by_id_selector(thread_message.id))
      end

      it "handles updates from multiple users sending messages in the thread" do
        using_session(:tab_1) do
          sign_in(current_user)
          chat_page.visit_channel(channel)
          channel_page.message_thread_indicator(thread.original_message).click
        end

        other_user = Fabricate(:user)
        chat_system_user_bootstrap(user: other_user, channel: channel)
        using_session(:tab_2) do
          sign_in(other_user)
          chat_page.visit_channel(channel)
          channel_page.message_thread_indicator(thread.original_message).click
        end

        using_session(:tab_2) do
          expect(side_panel).to have_open_thread(thread)
          open_thread.send_message(thread.id, "the other user message")
          expect(open_thread).to have_message(thread.id, text: "the other user message")
        end

        using_session(:tab_1) do
          expect(side_panel).to have_open_thread(thread)
          expect(open_thread).to have_message(thread.id, text: "the other user message")
          open_thread.send_message(thread.id, "this is a test message")
          expect(open_thread).to have_message(thread.id, text: "this is a test message")
        end

        using_session(:tab_2) do
          expect(open_thread).to have_message(thread.id, text: "this is a test message")
        end
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
