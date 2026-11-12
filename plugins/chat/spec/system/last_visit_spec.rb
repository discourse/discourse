# frozen_string_literal: true

RSpec.describe "Last visit" do
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: false) }
  fab!(:channel_2) { Fabricate(:chat_channel, threading_enabled: false) }

  fab!(:user_1, :user)
  fab!(:current_user, :user)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:sidebar_page) { PageObjects::Pages::ChatSidebar.new }

  before do
    chat_system_bootstrap
    channel_1.add(user_1)
    channel_1.add(current_user)
    channel_2.add(current_user)
    sign_in(current_user)
  end

  it "correctly updates the last visit line" do
    # a slightly complicated setup to ensure we test against a non trivial case
    message_1 = Fabricate(:chat_message, user: user_1, chat_channel: channel_1, use_service: true)
    Fabricate(:chat_message, user: user_1, chat_channel: channel_1, use_service: true)
    Fabricate(
      :chat_message,
      user: user_1,
      chat_channel: channel_1,
      in_reply_to: message_1,
      use_service: true,
    )
    chat_page.visit_channel(channel_1)

    expect(channel_page).to have_last_visit_line_at_id(message_1.id)

    sidebar_page.open_channel(channel_2)
    sidebar_page.open_channel(channel_1)

    expect(channel_page).to have_no_last_visit_line

    sidebar_page.open_channel(channel_2)
    message_4 = Fabricate(:chat_message, user: user_1, chat_channel: channel_1, use_service: true)
    sidebar_page.open_channel(channel_1)

    expect(channel_page).to have_last_visit_line_at_id(message_4.id)
  end

  it "keeps the last visit line when loading more messages" do
    past_limit = Chat::MessagesQuery::PAST_MESSAGE_LIMIT

    # more than a page of older messages, then the last read, then a couple
    # of unread messages for the last visit line
    messages = Fabricate.times(past_limit + 4, :chat_message, chat_channel: channel_1, user: user_1)
    channel_1.membership_for(current_user).update!(last_read_message_id: messages[-3].id)
    first_unread = messages[-2]

    chat_page.visit_channel(channel_1)
    expect(channel_page).to have_last_visit_line_at_id(first_unread.id)
    expect(channel_page.messages).to have_no_message(id: messages.first.id)

    # the older page loads in on scroll, and must not wipe the line
    channel_page.scroll_to_top

    expect(channel_page.messages).to have_message(id: messages.first.id)
    expect(channel_page).to have_last_visit_line_at_id(first_unread.id)
  end
end
