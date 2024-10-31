# frozen_string_literal: true

RSpec.describe Chat::Thread do
  before { SiteSetting.chat_enabled = true }

  describe ".ensure_consistency!" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_3) { Fabricate(:chat_thread, channel: channel) }

    fab!(:thread_1_message_1) { Fabricate(:chat_message, chat_channel: channel, thread: thread_1) }
    fab!(:thread_1_message_2) { Fabricate(:chat_message, chat_channel: channel, thread: thread_1) }
    fab!(:thread_1_message_3) { Fabricate(:chat_message, chat_channel: channel, thread: thread_1) }

    fab!(:thread_2_message_1) { Fabricate(:chat_message, chat_channel: channel, thread: thread_2) }
    fab!(:thread_2_message_2) { Fabricate(:chat_message, chat_channel: channel, thread: thread_2) }
    fab!(:thread_2_message_3) { Fabricate(:chat_message, chat_channel: channel, thread: thread_2) }
    fab!(:thread_2_message_4) { Fabricate(:chat_message, chat_channel: channel, thread: thread_2) }

    fab!(:thread_3_message_1) { Fabricate(:chat_message, chat_channel: channel, thread: thread_3) }

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

      it "does not attempt to clear caches if no replies_count caches are updated" do
        described_class.ensure_consistency!
        Chat::Thread.expects(:clear_caches!).never
        described_class.ensure_consistency!
      end
    end
  end

  describe ".clear_caches" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }

    before do
      thread_1.set_replies_count_cache(100)
      thread_2.set_replies_count_cache(100)
    end

    it "clears multiple keys" do
      Chat::Thread.clear_caches!([thread_1.id, thread_2.id])
      expect(Discourse.redis.get(Chat::Thread.replies_count_cache_redis_key(thread_1.id))).to eq(
        nil,
      )
      expect(
        Discourse.redis.get(Chat::Thread.replies_count_cache_updated_at_redis_key(thread_1.id)),
      ).to eq(nil)
      expect(Discourse.redis.get(Chat::Thread.replies_count_cache_redis_key(thread_2.id))).to eq(
        nil,
      )
      expect(
        Discourse.redis.get(Chat::Thread.replies_count_cache_updated_at_redis_key(thread_2.id)),
      ).to eq(nil)
    end

    it "wraps the ids into an array if only an integer is provided" do
      Chat::Thread.clear_caches!(thread_1.id)
      expect(Discourse.redis.get(Chat::Thread.replies_count_cache_redis_key(thread_1.id))).to eq(
        nil,
      )
      expect(
        Discourse.redis.get(Chat::Thread.replies_count_cache_updated_at_redis_key(thread_1.id)),
      ).to eq(nil)
    end
  end

  describe ".grouped_messages" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }

    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel, thread: thread_1) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel, thread: thread_1) }
    fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel, thread: thread_2) }

    let(:result) { Chat::Thread.grouped_messages(**params) }

    context "when thread_ids provided" do
      let(:params) { { thread_ids: [thread_1.id, thread_2.id] } }

      it "groups all the message ids in each thread by thread ID" do
        expect(result.find { |res| res.thread_id == thread_1.id }.to_h).to eq(
          {
            thread_message_ids: [thread_1.original_message_id, message_1.id, message_2.id],
            thread_id: thread_1.id,
            original_message_id: thread_1.original_message_id,
          },
        )
        expect(result.find { |res| res.thread_id == thread_2.id }.to_h).to eq(
          {
            thread_message_ids: [thread_2.original_message_id, message_3.id],
            thread_id: thread_2.id,
            original_message_id: thread_2.original_message_id,
          },
        )
      end

      context "when include_original_message is false" do
        let(:params) { { thread_ids: [thread_1.id, thread_2.id], include_original_message: false } }

        it "does not include the original message in the thread_message_ids" do
          expect(result.find { |res| res.thread_id == thread_1.id }.to_h).to eq(
            {
              thread_message_ids: [message_1.id, message_2.id],
              thread_id: thread_1.id,
              original_message_id: thread_1.original_message_id,
            },
          )
        end
      end
    end

    context "when message_ids provided" do
      let(:params) do
        {
          message_ids: [
            thread_1.original_message_id,
            thread_2.original_message_id,
            message_1.id,
            message_2.id,
            message_3.id,
          ],
        }
      end

      it "groups all the message ids in each thread by thread ID" do
        expect(result.find { |res| res.thread_id == thread_1.id }.to_h).to eq(
          {
            thread_message_ids: [thread_1.original_message_id, message_1.id, message_2.id],
            thread_id: thread_1.id,
            original_message_id: thread_1.original_message_id,
          },
        )
        expect(result.find { |res| res.thread_id == thread_2.id }.to_h).to eq(
          {
            thread_message_ids: [thread_2.original_message_id, message_3.id],
            thread_id: thread_2.id,
            original_message_id: thread_2.original_message_id,
          },
        )
      end

      context "when include_original_message is false" do
        let(:params) do
          {
            message_ids: [
              thread_1.original_message_id,
              thread_2.original_message_id,
              message_1.id,
              message_2.id,
              message_3.id,
            ],
            include_original_message: false,
          }
        end

        it "does not include the original message in the thread_message_ids" do
          expect(result.find { |res| res.thread_id == thread_1.id }.to_h).to eq(
            {
              thread_message_ids: [message_1.id, message_2.id],
              thread_id: thread_1.id,
              original_message_id: thread_1.original_message_id,
            },
          )
        end
      end
    end
  end

  describe "#latest_not_deleted_message_id" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel, old_om: true) }
    fab!(:old_message) { Fabricate(:chat_message, chat_channel: channel, thread: thread) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel, thread: thread) }

    before { old_message.update!(created_at: 1.day.ago) }

    it "accepts an anchor message to only get messages of a lower id" do
      expect(thread.latest_not_deleted_message_id(anchor_message_id: message_1.id)).to eq(
        old_message.id,
      )
    end

    it "gets the latest message by created_at" do
      expect(thread.latest_not_deleted_message_id).to eq(message_1.id)
    end

    it "does not get other channel messages" do
      Fabricate(:chat_message)
      expect(thread.latest_not_deleted_message_id).to eq(message_1.id)
    end

    it "does not get deleted messages" do
      message_1.trash!
      expect(thread.latest_not_deleted_message_id).to eq(old_message.id)
    end
  end

  describe "custom fields" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

    it "allows create and save" do
      thread.custom_fields["test"] = "test"
      thread.save_custom_fields
      loaded_thread = Chat::Thread.find(thread.id)
      expect(loaded_thread.custom_fields["test"]).to eq("test")
      expect(Chat::ThreadCustomField.first.thread.id).to eq(thread.id)
    end
  end
end
