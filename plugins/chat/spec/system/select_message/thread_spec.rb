# frozen_string_literal: true

RSpec.describe "Chat | Select message | thread", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }
  fab!(:original_message) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  fab!(:thread_message_1) do
    Fabricate(
      :chat_message,
      thread_id: thread_1.id,
      chat_channel: channel_1,
      in_reply_to: original_message,
    )
  end
  fab!(:thread_message_2) do
    Fabricate(
      :chat_message,
      thread_id: thread_1.id,
      chat_channel: channel_1,
      in_reply_to: original_message,
    )
  end
  fab!(:thread_message_3) do
    Fabricate(
      :chat_message,
      thread_id: thread_1.id,
      chat_channel: channel_1,
      in_reply_to: original_message,
    )
  end

  it "can select multiple messages" do
    chat_page.visit_thread(thread_1)

    thread_page.messages.select(thread_message_1)
    thread_page.messages.select(thread_message_2)

    expect(thread_page).to have_selected_messages(thread_message_1, thread_message_2)
  end

  it "can shift + click to select messages between the first and last" do
    chat_page.visit_thread(thread_1)
    thread_page.messages.select(thread_message_1)
    thread_page.messages.shift_select(thread_message_3)

    expect(thread_page).to have_selected_messages(
      thread_message_1,
      thread_message_2,
      thread_message_3,
    )
  end
end
