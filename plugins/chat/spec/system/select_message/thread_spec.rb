# frozen_string_literal: true

RSpec.describe "Chat | Select message | thread" do
  fab!(:current_user, :user)
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  fab!(:replies) do
    replies =
      Fabricate.times(
        3,
        :chat_message,
        thread: thread_1,
        chat_channel: channel_1,
        in_reply_to: thread_1.original_message,
      )
    thread_1.update_last_message_id!
    thread_1.update!(replies_count: replies.size)
    replies
  end

  it "selects multiple messages individually or with shift-click" do
    chat_page.visit_thread(thread_1)

    first_reply, second_reply, third_reply = replies
    thread_page.messages.select(first_reply)
    thread_page.messages.select(second_reply)

    expect(thread_page).to have_selected_messages(first_reply, second_reply)

    thread_page.selection_management.cancel
    expect(thread_page.selection_management).to be_not_visible

    thread_page.messages.select(first_reply)
    expect(page).to have_css(".chat-thread .chat-message-container.-selected", count: 1)
    expect(thread_page).to have_selected_messages(first_reply)

    thread_page.messages.shift_select(third_reply)

    expect(thread_page).to have_selected_messages(first_reply, second_reply, third_reply)
  end
end
