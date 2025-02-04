# frozen_string_literal: true

RSpec.describe "Last visit", type: :system do
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: false) }
  fab!(:channel_2) { Fabricate(:chat_channel, threading_enabled: false) }

  fab!(:user_1) { Fabricate(:user) }
  fab!(:current_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }

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
end
