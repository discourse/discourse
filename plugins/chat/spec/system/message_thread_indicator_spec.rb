# frozen_string_literal: true

describe "Thread indicator for chat messages" do
  fab!(:current_user, :user)
  fab!(:other_user, :user)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:open_thread) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap(current_user, [channel])
    sign_in(current_user)
  end

  context "when threading_enabled is false for the channel" do
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: false) }
    fab!(:thread) { create_thread_with_reply_excerpts([other_user, current_user]) }

    it "shows no thread indicators in the channel" do
      chat_page.visit_channel(channel)
      expect(channel_page).to have_no_thread_indicator(thread.original_message)
    end
  end

  context "when threading is enabled for the channel" do
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread_1) do
      create_thread_with_reply_excerpts([other_user, current_user, other_user, current_user])
    end

    it "shows the reply count but no participant avatars when there is only one participant" do
      single_user_thread =
        create_thread_with_reply_excerpts([current_user, current_user, current_user])

      chat_page.visit_channel(channel)
      expect(
        channel_page.message_thread_indicator(single_user_thread.original_message),
      ).to have_reply_count(2)
      expect(
        channel_page.message_thread_indicator(single_user_thread.original_message),
      ).to have_no_participants
    end

    it "shows the thread indicator and hides the sent message when a user first replies to a message without a thread" do
      message_without_thread = Fabricate(:chat_message, chat_channel: channel, user: other_user)
      chat_page.visit_channel(channel)
      channel_page.reply_to(message_without_thread)
      open_thread.fill_composer("this is a reply to make a new thread")
      open_thread.click_send_message

      expect(channel_page).to have_thread_indicator(message_without_thread)

      new_thread = message_without_thread.reload.thread

      expect(page).not_to have_css(channel_page.message_by_id_selector(new_thread.replies.first))
    end

    it "shows thread indicators with counts and participants, and updates the count after replying" do
      thread_2 = create_thread_with_reply_excerpts([other_user, current_user])
      chat_page.visit_channel(channel)

      expect(channel_page).to have_thread_indicator(thread_1.original_message)
      expect(channel_page).to have_thread_indicator(thread_2.original_message)
      first_indicator = channel_page.message_thread_indicator(thread_1.original_message)
      expect(first_indicator).to have_reply_count(3)
      expect(channel_page.message_thread_indicator(thread_2.original_message)).to have_reply_count(
        1,
      )
      expect(first_indicator).to have_participant(current_user)
      expect(first_indicator).to have_participant(other_user)

      first_indicator.click

      expect(side_panel).to have_open_thread(thread_1)

      open_thread.send_message

      expect(first_indicator).to have_reply_count(4)
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

  private

  def create_thread_with_reply_excerpts(authors)
    original_author, *reply_authors = authors
    thread =
      chat_thread_with_replies(
        channel: channel,
        original_message_user: original_author,
        reply_users: reply_authors,
        link_replies: true,
      )
    channel.add(original_author).mark_read!(thread.original_message_id)
    thread.replies.each do |reply|
      reply.update!(excerpt: reply.build_excerpt)
      channel.add(reply.user)
      thread.add(reply.user).mark_read!(reply.id)
    end
    channel.update_last_message_id!
    thread
  end
end
