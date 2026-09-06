# frozen_string_literal: true

RSpec.describe Jobs::Chat::MarkAllChannelThreadsRead do
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
  fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }
  fab!(:other_channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:other_thread) { Fabricate(:chat_thread, channel: other_channel) }
  fab!(:user_1, :user)
  fab!(:user_2, :user)
  fab!(:thread_1_message_1) { Fabricate(:chat_message, thread: thread_1, chat_channel: channel) }
  fab!(:thread_1_message_2) { Fabricate(:chat_message, thread: thread_1, chat_channel: channel) }
  fab!(:thread_1_message_3) { Fabricate(:chat_message, thread: thread_1, chat_channel: channel) }
  fab!(:thread_2_message_1) { Fabricate(:chat_message, thread: thread_2, chat_channel: channel) }
  fab!(:thread_2_message_2) { Fabricate(:chat_message, thread: thread_2, chat_channel: channel) }
  fab!(:other_thread_message) do
    Fabricate(:chat_message, thread: other_thread, chat_channel: other_channel)
  end

  before do
    channel.add(user_1)
    channel.add(user_2)
    thread_1.add(user_1)
    thread_1.update!(last_message: thread_1_message_3)
    thread_2.add(user_2)
    thread_2.update!(last_message: thread_2_message_2)
    other_channel.add(user_1)
    other_thread.add(user_1)
    other_thread.update!(last_message: other_thread_message)
  end

  def unread_count(user, target_channel = channel)
    Chat::ThreadUnreadsQuery
      .call(channel_ids: [target_channel.id], user_id: user.id)
      .first
      .unread_count
  end

  it "marks all threads as read across all users in the channel" do
    expect(unread_count(user_1)).to eq(3)
    expect(unread_count(user_2)).to eq(2)
    described_class.new.execute(channel_id: channel.id)
    expect(unread_count(user_1)).to eq(0)
    expect(unread_count(user_2)).to eq(0)
  end

  it "does not mark threads in other channels as read" do
    expect(unread_count(user_1, other_channel)).to eq(1)
    described_class.new.execute(channel_id: channel.id)
    expect(unread_count(user_1, other_channel)).to eq(1)
  end
end
