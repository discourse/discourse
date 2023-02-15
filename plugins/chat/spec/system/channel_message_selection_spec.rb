# frozen_string_literal: true

RSpec.describe "Channel message selection", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
  fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }
  fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  it "can select multiple messages" do
    chat.visit_channel(channel_1)
    channel.select_message(message_1)

    expect(page).to have_css(".chat-selection-management")

    channel.message_by_id(message_2.id).find(".chat-message-selector").click
    expect(page).to have_css(".chat-message-selector:checked", count: 2)
  end

  it "can shift + click to select messages between the first and last" do
    chat.visit_channel(channel_1)
    channel.select_message(message_1)

    expect(page).to have_css(".chat-selection-management")

    channel.message_by_id(message_3.id).find(".chat-message-selector").click(:shift)
    expect(page).to have_css(".chat-message-selector:checked", count: 3)
  end

  context "when visiting another channel" do
    fab!(:channel_2) { Fabricate(:chat_channel) }

    before { channel_2.add(current_user) }

    it "resets message selection" do
      chat.visit_channel(channel_1)
      channel.select_message(message_1)

      expect(page).to have_css(".chat-selection-management")

      chat.visit_channel(channel_2)

      expect(page).to have_no_css(".chat-selection-management")
    end
  end
end
