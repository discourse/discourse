# frozen_string_literal: true

describe "Thread indicator for chat messages", type: :system do
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
      expect(channel_page).to have_no_thread_indicator(thread.original_message)
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
      expect(channel_page).to have_no_thread_indicator(thread.original_message)
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
      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_reply_count(
        3,
      )
      expect(channel_page.message_thread_indicator(thread_2.original_message)).to have_reply_count(
        1,
      )
    end

    it "it shows the reply count but no participant avatars when there is only one participant" do
      single_user_thread =
        Fabricate(:chat_thread, channel: channel, original_message_user: current_user)
      Fabricate(:chat_message, thread: single_user_thread, user: current_user)
      Fabricate(:chat_message, thread: single_user_thread, user: current_user)
      chat_page.visit_channel(channel)
      expect(
        channel_page.message_thread_indicator(single_user_thread.original_message),
      ).to have_reply_count(2)
      expect(
        channel_page.message_thread_indicator(single_user_thread.original_message),
      ).to have_no_participants
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
      open_thread.fill_composer("this is a reply to make a new thread")
      open_thread.click_send_message

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

      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_reply_count(
        3,
      )

      channel_page.message_thread_indicator(thread_1.original_message).click

      expect(side_panel).to have_open_thread(thread_1)

      open_thread.send_message

      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_reply_count(
        4,
      )
    end

    it "shows avatars for the participants of the thread" do
      chat_page.visit_channel(channel)
      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_participant(
        current_user,
      )
      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_participant(
        other_user,
      )
    end

    it "shows an excerpt of the last reply in the thread" do
      thread_1.last_message.update!(message: "test for excerpt")
      thread_1.last_message.rebake!

      chat_page.visit_channel(channel)
      expect(
        channel_page.message_thread_indicator(thread_1.original_message).excerpt,
      ).to have_content(thread_excerpt(thread_1.last_message))
    end

    it "updates the last reply excerpt and participants when a new message is added to the thread" do
      new_user = Fabricate(:user)
      chat_system_user_bootstrap(user: new_user, channel: channel)
      original_last_reply = thread_1.last_message
      original_last_reply.update!(message: "test for excerpt")
      original_last_reply.rebake!

      chat_page.visit_channel(channel)

      excerpt_text = thread_excerpt(original_last_reply)

      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_content(
        excerpt_text,
      )

      using_session(:new_user) do |session|
        sign_in(new_user)
        chat_page.visit_channel(channel)
        channel_page.message_thread_indicator(thread_1.original_message).click

        expect(side_panel).to have_open_thread(thread_1)

        open_thread.send_message("wow i am happy to join this thread!")
      end

      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_participant(
        new_user,
      )

      new_user_reply = thread_1.replies.where(user: new_user).first
      excerpt_text = thread_excerpt(new_user_reply)

      expect(
        channel_page.message_thread_indicator(thread_1.original_message).excerpt,
      ).to have_content(excerpt_text)
    end
  end
end
