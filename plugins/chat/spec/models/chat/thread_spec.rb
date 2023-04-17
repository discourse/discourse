# frozen_string_literal: true

RSpec.describe Chat::Thread do
  describe ".ensure_consistency!" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_3) { Fabricate(:chat_thread, channel: channel) }

    before do
      Fabricate(:chat_message, chat_channel: channel, thread: thread_1)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_1)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_1)

      Fabricate(:chat_message, chat_channel: channel, thread: thread_2)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_2)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_2)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_2)

      Fabricate(:chat_message, chat_channel: channel, thread: thread_3)
    end

    describe "updating replies_count for all threads" do
      it "counts correctly and does not include the original message" do
        described_class.ensure_consistency!
        expect(thread_1.reload.replies_count).to eq(3)
        expect(thread_2.reload.replies_count).to eq(4)
        expect(thread_3.reload.replies_count).to eq(1)
      end

      it "does not count deleted messages" do
        thread_1.chat_messages.last.trash!
        described_class.ensure_consistency!
        expect(thread_1.reload.replies_count).to eq(2)
      end

      it "sets the replies count to 0 if all the messages but the original message are deleted" do
        thread_1.replies.delete_all

        described_class.ensure_consistency!
        expect(thread_1.reload.replies_count).to eq(0)
      end

      it "clears the affected replies_count caches" do
        thread_1.set_replies_count_cache(100)
        expect(thread_1.replies_count_cache).to eq(100)
        expect(thread_1.replies_count_cache_updated_at).not_to eq(nil)

        described_class.ensure_consistency!
        expect(Discourse.redis.get(Chat::Thread.replies_count_cache_redis_key(thread_1.id))).to eq(
          nil,
        )
        expect(
          Discourse.redis.get(Chat::Thread.replies_count_cache_updated_at_redis_key(thread_1.id)),
        ).to eq(nil)
      end
    end
  end
end
