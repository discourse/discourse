# frozen_string_literal: true

describe "Channel thread message echoing", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap(current_user, [channel])
    sign_in(current_user)
  end

  context "when threading_enabled is false for the channel" do
    fab!(:channel) { Fabricate(:chat_channel) }
    before { channel.update!(threading_enabled: false) }

    it "echoes the thread messages into the main channel stream" do
      thread = chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
      chat_page.visit_channel(channel)
      thread.chat_messages.each do |thread_message|
        expect(channel_page).to have_css(channel_page.message_by_id_selector(thread_message.id))
      end
    end
  end

  context "when threading is enabled for the channel" do
    fab!(:channel) { Fabricate(:chat_channel) }
    fab!(:thread) do
      chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
    end

    before { channel.update!(threading_enabled: true) }

    it "does not echo the thread messages except for the original message into the channel stream" do
      chat_page.visit_channel(channel)
      expect(channel_page).to have_css(
        channel_page.message_by_id_selector(thread.original_message.id),
      )
      thread.replies.each do |thread_message|
        expect(channel_page).not_to have_css(channel_page.message_by_id_selector(thread_message.id))
      end
    end

    it "does not echo new thread messages into the channel stream" do
      chat_page.visit_channel(channel)
      channel_page.message_thread_indicator(thread.original_message).click
      expect(side_panel).to have_open_thread(thread)
      thread_page.send_message("new thread message")
      expect(thread_page.messages).to have_message(thread_id: thread.id, text: "new thread message")
      new_message = thread.reload.replies.last
      expect(channel_page).not_to have_css(channel_page.message_by_id_selector(new_message.id))
    end

    it "does not echo the looked up message into the channel stream if it is in a thread" do
      current_user
        .user_chat_channel_memberships
        .find_by(chat_channel: channel)
        .update!(last_read_message_id: thread.last_message_id)
      chat_page.visit_channel(channel)
      expect(channel_page).not_to have_css(
        channel_page.message_by_id_selector(thread.last_message_id),
      )
    end

    it "does show the thread original_message if it is the last message in the channel" do
      new_thread = Fabricate(:chat_thread, channel: channel)
      current_user
        .user_chat_channel_memberships
        .find_by(chat_channel: channel)
        .update!(last_read_message_id: new_thread.original_message_id)
      chat_page.visit_channel(channel)
      expect(channel_page).to have_css(
        channel_page.message_by_id_selector(new_thread.original_message_id),
      )
    end
  end
end
