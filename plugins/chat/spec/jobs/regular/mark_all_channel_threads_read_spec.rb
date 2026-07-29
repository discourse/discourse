# frozen_string_literal: true

RSpec.describe Jobs::Chat::MarkAllChannelThreadsRead do
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
  fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }
  fab!(:user_1, :user)
  fab!(:user_2, :user)
  fab!(:thread_1_message_1) { Fabricate(:chat_message, thread: thread_1, chat_channel: channel) }
  fab!(:thread_1_message_2) { Fabricate(:chat_message, thread: thread_1, chat_channel: channel) }
  fab!(:thread_1_message_3) { Fabricate(:chat_message, thread: thread_1, chat_channel: channel) }
  fab!(:thread_2_message_1) { Fabricate(:chat_message, thread: thread_2, chat_channel: channel) }
  fab!(:thread_2_message_2) { Fabricate(:chat_message, thread: thread_2, chat_channel: channel) }

  before do
    channel.add(user_1)
    channel.add(user_2)
    thread_1.add(user_1)
    thread_1.update!(last_message: thread_1_message_3)
    thread_2.add(user_2)
    thread_2.update!(last_message: thread_2_message_2)
  end

  it "marks all threads as read across all users in the channel" do
    expect(
      Chat::ThreadUnreadsQuery
        .call(channel_ids: [channel.id], user_id: user_1.id)
        .first
        .unread_count,
    ).to eq(3)
    expect(
      Chat::ThreadUnreadsQuery
        .call(channel_ids: [channel.id], user_id: user_2.id)
        .first
        .unread_count,
    ).to eq(2)

    described_class.new.execute(channel_id: channel.id)

    expect(
      Chat::ThreadUnreadsQuery
        .call(channel_ids: [channel.id], user_id: user_1.id)
        .first
        .unread_count,
    ).to eq(0)
    expect(
      Chat::ThreadUnreadsQuery
        .call(channel_ids: [channel.id], user_id: user_2.id)
        .first
        .unread_count,
    ).to eq(0)
  end
end
