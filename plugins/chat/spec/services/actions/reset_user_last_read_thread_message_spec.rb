# frozen_string_literal: true

RSpec.describe Chat::Action::ResetUserLastReadThreadMessage do
  fab!(:thread_1) { Fabricate(:chat_thread) }
  fab!(:thread_2) { Fabricate(:chat_thread) }
  fab!(:message_1) do
    Fabricate(
      :chat_message,
      chat_channel: thread_1.channel,
      thread: thread_1,
      created_at: 1.hour.ago,
    )
  end
  fab!(:message_2) do
    Fabricate(
      :chat_message,
      chat_channel: thread_1.channel,
      thread: thread_1,
      created_at: 2.seconds.ago,
    )
  end
  fab!(:message_3) do
    Fabricate(
      :chat_message,
      chat_channel: thread_1.channel,
      thread: thread_1,
      created_at: 3.minutes.ago,
    )
  end
  fab!(:message_4) do
    Fabricate(
      :chat_message,
      chat_channel: thread_2.channel,
      thread: thread_2,
      created_at: 30.seconds.ago,
    )
  end
  fab!(:message_5) do
    Fabricate(
      :chat_message,
      chat_channel: thread_2.channel,
      thread: thread_2,
      created_at: 3.seconds.ago,
    )
  end
  fab!(:message_6) do
    Fabricate(
      :chat_message,
      chat_channel: thread_2.channel,
      thread: thread_2,
      created_at: 1.day.ago,
    )
  end
  fab!(:membership_1) do
    Fabricate(:user_chat_thread_membership, thread: thread_1, last_read_message_id: message_3.id)
  end
  fab!(:membership_2) do
    Fabricate(:user_chat_thread_membership, thread: thread_2, last_read_message_id: message_6.id)
  end

  context "when there are non-deleted messages left in the thread" do
    before do
      message_3.trash!
      message_6.trash!
    end

    it "sets the matching membership last_read_message_ids to the most recently created message ID" do
      described_class.call([message_3.id, message_6.id], [thread_1.id, thread_2.id])
      expect(membership_1.reload.last_read_message_id).to eq(message_2.id)
      expect(membership_2.reload.last_read_message_id).to eq(message_5.id)
    end
  end

  context "when there are no more non-deleted messages left in the thread (excluding the original message)" do
    before { [message_1, message_2, message_4, message_5].each(&:trash!) }

    it "sets the matching membership last_read_message_ids to NULL" do
      described_class.call([message_3.id, message_6.id], [thread_1.id, thread_2.id])
      expect(membership_1.reload.last_read_message_id).to be_nil
      expect(membership_2.reload.last_read_message_id).to be_nil
    end
  end
end
