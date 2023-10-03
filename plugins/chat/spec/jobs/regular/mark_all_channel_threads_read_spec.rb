# frozen_string_literal: true

RSpec.describe Jobs::Chat::MarkAllChannelThreadsRead do
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
  fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
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

  def unread_count(user)
    Chat::ThreadUnreadsQuery.call(channel_ids: [channel.id], user_id: user.id).first.unread_count
  end

  it "marks all threads as read across all users in the channel" do
    expect(unread_count(user_1)).to eq(3)
    expect(unread_count(user_2)).to eq(2)
    described_class.new.execute(channel_id: channel.id)
    expect(unread_count(user_1)).to eq(0)
    expect(unread_count(user_2)).to eq(0)
  end
end
