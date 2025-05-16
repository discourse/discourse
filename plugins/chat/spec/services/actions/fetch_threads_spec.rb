# frozen_string_literal: true

RSpec.describe Chat::Action::FetchThreads do
  subject(:threads) do
    described_class.call(user_id: current_user.id, channel_id: channel.id, limit:, offset:)
  end

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel:) }
  fab!(:thread_2) { Fabricate(:chat_thread, channel:) }
  fab!(:thread_3) { Fabricate(:chat_thread, channel:) }

  let(:limit) { 10 }
  let(:offset) { 0 }

  before do
    channel.add(current_user)
    [thread_1, thread_2, thread_3].each.with_index do |t, index|
      t.original_message.update!(created_at: (index + 1).weeks.ago)
      t.update!(replies_count: 2)
      t.add(current_user)
    end
  end

  context "when there are new messages" do
    before do
      [
        [thread_1, 10.minutes.ago],
        [thread_2, 1.day.ago],
        [thread_3, 2.seconds.ago],
      ].each do |thread, created_at|
        message =
          Fabricate(:chat_message, user: current_user, chat_channel: channel, thread:, created_at:)
        thread.update!(last_message: message)
      end
    end

    it "orders threads by the last reply created_at timestamp" do
      expect(threads.map(&:id)).to eq([thread_3.id, thread_1.id, thread_2.id])
    end
  end

  context "when there are unread messages" do
    let(:unread_message) { Fabricate(:chat_message, chat_channel: channel, thread: thread_2) }

    before do
      unread_message.update!(created_at: 2.days.ago)
      thread_2.update!(last_message: unread_message)
    end

    it "sorts by unread over recency" do
      expect(threads.map(&:id)).to eq([thread_2.id, thread_1.id, thread_3.id])
    end
  end

  context "when there are more threads than the limit" do
    let(:limit) { 5 }
    let(:thread_4) { Fabricate(:chat_thread, channel:) }
    let(:thread_5) { Fabricate(:chat_thread, channel:) }
    let(:thread_6) { Fabricate(:chat_thread, channel:) }
    let(:thread_7) { Fabricate(:chat_thread, channel:) }

    before do
      [thread_4, thread_5, thread_6, thread_7].each do |t|
        t.update!(replies_count: 2)
        t.add(current_user)
        t.membership_for(current_user).mark_read!
      end
      [thread_1, thread_2, thread_3].each { |t| t.membership_for(current_user).mark_read! }
      # The old unread messages.
      Fabricate(:chat_message, chat_channel: channel, thread: thread_7).update!(
        created_at: 2.months.ago,
      )
      Fabricate(:chat_message, chat_channel: channel, thread: thread_6).update!(
        created_at: 3.months.ago,
      )
    end

    it "sorts very old unreads to top over recency, and sorts both unreads and other threads by recency" do
      expect(threads.map(&:id)).to eq(
        [thread_7.id, thread_6.id, thread_5.id, thread_4.id, thread_1.id],
      )
    end
  end

  context "when the original message is trashed" do
    before { thread_1.original_message.trash! }

    it "does not return its associated thread" do
      expect(threads.map(&:id)).to eq([thread_2.id, thread_3.id])
    end
  end

  context "when the original message is deleted" do
    before { thread_1.original_message.destroy }

    it "does not return the associated thread" do
      expect(threads.map(&:id)).to eq([thread_2.id, thread_3.id])
    end
  end

  context "when there are threads in other channels" do
    let(:thread_4) { Fabricate(:chat_thread) }
    let!(:message) do
      Fabricate(
        :chat_message,
        user: current_user,
        thread: thread_4,
        chat_channel: thread_4.channel,
        created_at: 2.seconds.ago,
      )
    end

    it "does not return those threads" do
      expect(threads.map(&:id)).to eq([thread_1.id, thread_2.id, thread_3.id])
    end
  end

  context "when there is a thread with no membership" do
    let(:thread_4) { Fabricate(:chat_thread, channel:) }

    before { thread_4.update!(replies_count: 2) }

    it "returns every threads of the channel, no matter the tracking notification level or membership" do
      expect(threads.map(&:id)).to match_array([thread_1.id, thread_2.id, thread_3.id, thread_4.id])
    end
  end

  context "when there are muted threads" do
    let(:thread) { Fabricate(:chat_thread, channel:) }

    before do
      thread.add(current_user)
      thread.membership_for(current_user).update!(
        notification_level: ::Chat::UserChatThreadMembership.notification_levels[:muted],
      )
    end

    it "does not return them" do
      expect(threads.map(&:id)).not_to include(thread.id)
    end
  end

  context "when there are deleted messages" do
    let!(:original_last_message_id) { thread_3.reload.last_message_id }
    let(:unread_message) { Fabricate(:chat_message, chat_channel: channel, thread: thread_3) }

    before do
      unread_message.update!(created_at: 2.days.ago)
      unread_message.trash!
      thread_3.reload.update!(last_message_id: original_last_message_id)
    end

    it "does not count deleted messages for sort order" do
      expect(threads.map(&:id)).to eq([thread_1.id, thread_2.id, thread_3.id])
    end
  end

  context "when offset param is set" do
    let(:offset) { 1 }

    it "returns results from the offset the number of threads returned" do
      expect(threads).to eq([thread_2, thread_3])
    end
  end
end
