# frozen_string_literal: true

RSpec.describe "Update last read", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:messages) { Fabricate.times(15, :chat_message, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:membership) { Chat::ChannelMembershipManager.new(channel_1).find_for_user(current_user) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)

    membership.update!(last_read_message_id: messages.last.id)
    sign_in(current_user)
  end

  context "when the full message is visible" do
    it "marks it as read" do
      last_message = Fabricate(:chat_message, chat_channel: channel_1)
      chat_page.visit_channel(channel_1)

      try_until_success { expect(membership.reload.last_read_message_id).to eq(last_message.id) }
    end
  end

  context "when receiving a messages" do
    it "marks it as read" do
      chat_page.visit_channel(channel_1)

      last_message = Fabricate(:chat_message, chat_channel: channel_1, use_service: true)

      try_until_success { expect(membership.reload.last_read_message_id).to eq(last_message.id) }
    end
  end

  context "when user had not previous last read" do
    before { membership.update!(last_read_message_id: nil) }

    it "marks last message as read" do
      last_message = Fabricate(:chat_message, chat_channel: channel_1)
      chat_page.visit_channel(channel_1)

      try_until_success { expect(membership.reload.last_read_message_id).to eq(last_message.id) }
    end
  end
end
