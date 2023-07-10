# frozen_string_literal: true

require Rails.root.join(
          "plugins/chat/db/migrate/20230707082645_backfill_chat_channel_and_thread_last_message_ids.rb",
        )

RSpec.describe BackfillChatChannelAndThreadLastMessageIds do
  def run_migration
    described_class.new.up
  end

  describe "for channels" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:channel_2) { Fabricate(:category_channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel) }

    it "does not set the last message id to a deleted message" do
      message_2.trash!
      run_migration
      expect(channel.reload.last_message_id).to eq(message_1.id)
    end

    it "does not set the last message id to a thread reply" do
      thread = Fabricate(:chat_thread, channel: channel)
      message_2.update!(thread: thread)
      run_migration
      expect(channel.reload.last_message_id).to eq(message_1.id)
    end

    it "can set the last message id to a thread original message" do
      thread = Fabricate(:chat_thread, channel: channel)
      message_1.update!(created_at: thread.original_message.created_at - 3.hours)
      message_2.update!(created_at: thread.original_message.created_at - 2.hours)
      run_migration
      expect(channel.reload.last_message_id).to eq(thread.original_message_id)
    end

    it "does not set an older message as the last message id" do
      run_migration
      expect(channel.reload.last_message_id).to eq(message_2.id)
    end

    it "does not error for channels with no messages" do
      no_message_channel = Fabricate(:category_channel)
      run_migration
      expect(no_message_channel.reload.last_message_id).to eq(nil)
    end
  end

  describe "for threads" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel, thread: thread) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel, thread: thread) }

    it "does not set the last message id to a deleted message" do
      message_2.trash!
      run_migration
      expect(thread.reload.last_message_id).to eq(message_1.id)
    end

    it "can set the last message id to a thread original message" do
      message_1.trash!
      message_2.trash!
      run_migration
      expect(thread.reload.last_message_id).to eq(thread.original_message_id)
    end

    it "does not set an older message as the last message id" do
      run_migration
      expect(thread.reload.last_message_id).to eq(message_2.id)
    end

    it "does not error for threads with no messages" do
      no_message_thread = Fabricate(:chat_thread)
      no_message_thread.original_message.trash!
      run_migration
      expect(no_message_thread.reload.last_message_id).to eq(nil)
    end
  end
end
