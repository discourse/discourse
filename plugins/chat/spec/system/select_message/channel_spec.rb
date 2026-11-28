# frozen_string_literal: true

RSpec.describe "Chat | Select message | channel" do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
  fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }
  fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  it "selects multiple messages individually or with shift-click" do
    chat_page.visit_channel(channel_1)

    channel_page.messages.select(message_1)
    channel_page.messages.select(message_2)

    expect(channel_page).to have_selected_messages(message_1, message_2)

    channel_page.selection_management.cancel
    expect(channel_page.selection_management).to be_not_visible

    channel_page.messages.select(message_1)
    expect(page).to have_css(".chat-channel .chat-message-container.-selected", count: 1)
    expect(channel_page).to have_selected_messages(message_1)

    channel_page.messages.shift_select(message_3)

    expect(channel_page).to have_selected_messages(message_1, message_2, message_3)
  end

  context "when visiting another channel" do
    fab!(:channel_2, :chat_channel)

    before { channel_2.add(current_user) }

    it "resets message selection" do
      chat_page.visit_channel(channel_1)
      channel_page.messages.select(message_1)

      expect(channel_page.selection_management).to be_visible

      chat_page.visit_channel(channel_2)

      expect(page).to have_css(".chat-channel.--loaded[data-id='#{channel_2.id}']")
      expect(channel_page.selection_management).to be_not_visible
    end
  end
end
