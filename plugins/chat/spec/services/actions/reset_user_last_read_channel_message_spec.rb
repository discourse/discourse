# frozen_string_literal: true

RSpec.describe Chat::Action::ResetUserLastReadChannelMessage do
  fab!(:channel_1, :chat_channel)
  fab!(:channel_2, :chat_channel)
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, created_at: 1.hour.ago) }
  fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, created_at: 2.seconds.ago) }
  fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_1, created_at: 3.minutes.ago) }
  fab!(:message_4) { Fabricate(:chat_message, chat_channel: channel_2, created_at: 30.seconds.ago) }
  fab!(:message_5) { Fabricate(:chat_message, chat_channel: channel_2, created_at: 3.seconds.ago) }
  fab!(:message_6) { Fabricate(:chat_message, chat_channel: channel_2, created_at: 1.day.ago) }
  fab!(:membership_1) do
    Fabricate(
      :user_chat_channel_membership,
      chat_channel: channel_1,
      last_read_message_id: message_3.id,
    )
  end
  fab!(:membership_2) do
    Fabricate(
      :user_chat_channel_membership,
      chat_channel: channel_2,
      last_read_message_id: message_6.id,
    )
  end

  context "when there are non-deleted messages left in the channel" do
    before do
      message_3.trash!
      message_3.chat_channel.update_last_message_id!
      message_6.trash!
      message_6.chat_channel.update_last_message_id!
    end

    it "sets the matching membership last_read_message_ids to the most recently created message ID" do
      described_class.call([message_3.id, message_6.id], [channel_1.id, channel_2.id])
      expect(membership_1.reload.last_read_message_id).to eq(message_2.id)
      expect(membership_2.reload.last_read_message_id).to eq(message_5.id)
    end
  end

  context "when there are no more non-deleted messages left in the channel" do
    before do
      [message_1, message_2, message_4, message_5].each(&:trash!)
      channel_1.update_last_message_id!
      channel_2.update_last_message_id!
    end

    it "sets the matching membership last_read_message_ids to NULL" do
      described_class.call([message_3.id, message_6.id], [channel_1.id, channel_2.id])
      expect(membership_1.reload.last_read_message_id).to be_nil
      expect(membership_2.reload.last_read_message_id).to be_nil
    end
  end
end
