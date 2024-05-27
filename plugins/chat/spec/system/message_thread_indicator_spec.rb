# frozen_string_literal: true

describe "Thread indicator for chat messages", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:open_thread) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap(current_user, [channel])
    sign_in(current_user)
  end

  context "when threading_enabled is false for the channel" do
    fab!(:channel) { Fabricate(:chat_channel) }
    before { channel.update!(threading_enabled: false) }

    it "shows no thread inidcators in the channel" do
      thread = chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
      chat_page.visit_channel(channel)
      expect(channel_page).to have_no_thread_indicator(thread.original_message)
    end
  end

  context "when threading is enabled for the channel" do
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

    before { channel.update!(threading_enabled: true) }

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
        chat_thread_chain_bootstrap(channel: channel, users: [current_user], messages_count: 3)

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
      update_message!(
        thread_1.original_message,
        user: thread_1.original_message.user,
        text: "test for excerpt",
      )

      chat_page.visit_channel(channel)

      expect(
        channel_page.message_thread_indicator(thread_1.original_message.reload).excerpt,
      ).to have_content(thread_excerpt(thread_1.last_message.reload))
    end

    it "builds an excerpt for the last reply if it doesn’t have one" do
      thread_1.last_message.update!(excerpt: nil)
      chat_page.visit_channel(channel)

      expect(
        channel_page.message_thread_indicator(thread_1.original_message).excerpt,
      ).to have_content(thread_1.last_message.build_excerpt)
    end

    it "updates the last reply excerpt and participants when a new message is added to the thread" do
      new_user = Fabricate(:user)
      chat_system_user_bootstrap(user: new_user, channel: channel)
      original_last_reply = thread_1.last_message
      update_message!(original_last_reply, user: original_last_reply.user, text: "test for excerpt")

      chat_page.visit_channel(channel)

      excerpt_text = thread_excerpt(original_last_reply.reload)

      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_content(
        excerpt_text,
      )

      new_message =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          thread: thread_1,
          user: new_user,
          in_reply_to: thread_1.original_message,
          use_service: true,
        )

      expect(channel_page.message_thread_indicator(thread_1.original_message)).to have_participant(
        new_user,
      )
      expect(
        channel_page.message_thread_indicator(thread_1.original_message).excerpt,
      ).to have_content(thread_excerpt(new_message))
    end
  end
end
