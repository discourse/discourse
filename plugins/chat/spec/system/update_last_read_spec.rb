# frozen_string_literal: true

RSpec.describe "Update last read" do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:sender, :user)
  fab!(:previous_message) { Fabricate(:chat_message, chat_channel: channel_1, user: sender) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:membership) { Chat::ChannelMembershipManager.new(channel_1).find_for_user(current_user) }

  before do
    chat_system_bootstrap
    channel_1.update!(last_message: previous_message, messages_count: 1)
    channel_1.add(current_user)
    channel_1.add(sender).mark_read!(previous_message.id)

    membership.update!(last_read_message_id: previous_message.id)
    sign_in(current_user)
  end

  context "when the full message is visible" do
    it "marks it as read" do
      last_message = Fabricate(:chat_message, chat_channel: channel_1, user: sender)
      channel_1.update!(last_message:, messages_count: 2)
      channel_1.membership_for(sender).mark_read!(last_message.id)
      chat_page.visit_channel(channel_1)

      try_until_success(
        reason: "Relies on Ember timer to fire off request to update last_read_message_id",
      ) { expect(membership.reload.last_read_message_id).to eq(last_message.id) }
    end
  end

  context "when receiving a message" do
    it "marks it as read" do
      chat_page.visit_channel(channel_1)

      result =
        Chat::CreateMessage.call(
          guardian: sender.guardian,
          params: {
            chat_channel_id: channel_1.id,
            message: fake_chat_message,
          },
        )
      service_failed!(result) if result.failure?
      last_message = result.message_instance

      try_until_success(
        reason: "Relies on Ember timer to fire off request to update last_read_message_id",
      ) { expect(membership.reload.last_read_message_id).to eq(last_message.id) }
    end
  end

  context "when user had not previous last read" do
    before { membership.update!(last_read_message_id: nil) }

    it "marks last message as read" do
      last_message = Fabricate(:chat_message, chat_channel: channel_1, user: sender)
      channel_1.update!(last_message:, messages_count: 2)
      channel_1.membership_for(sender).mark_read!(last_message.id)
      chat_page.visit_channel(channel_1)

      try_until_success(
        reason: "Relies on Ember timer to fire off request to update last_read_message_id",
      ) { expect(membership.reload.last_read_message_id).to eq(last_message.id) }
    end
  end
end
