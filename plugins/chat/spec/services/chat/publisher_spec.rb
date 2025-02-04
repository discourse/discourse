# frozen_string_literal: true

describe Chat::Publisher do
  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }

  describe ".publish_delete!" do
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel) }
    before { message_2.trash! }

    it "publishes the correct data" do
      data =
        MessageBus.track_publish { described_class.publish_delete!(channel, message_2) }[0].data

      expect(data["deleted_at"]).to eq(message_2.deleted_at.iso8601(3))
      expect(data["deleted_by_id"]).to eq(message_2.deleted_by_id)
      expect(data["deleted_id"]).to eq(message_2.id)
      expect(data["latest_not_deleted_message_id"]).to eq(message_1.id)
      expect(data["type"]).to eq("delete")
    end

    context "when there are no earlier messages in the channel to send as latest_not_deleted_message_id" do
      it "publishes nil" do
        data =
          MessageBus.track_publish { described_class.publish_delete!(channel, message_1) }[0].data

        expect(data["latest_not_deleted_message_id"]).to eq(nil)
      end
    end

    context "when the message is in a thread and the channel has threading_enabled" do
      before do
        thread = Fabricate(:chat_thread, channel: channel)
        message_1.update!(thread: thread)
        message_2.update!(thread: thread)
        channel.update!(threading_enabled: true)
      end

      it "publishes the correct latest not deleted message id" do
        data =
          MessageBus.track_publish { described_class.publish_delete!(channel, message_2) }[0].data

        expect(data["deleted_at"]).to eq(message_2.deleted_at.iso8601(3))
        expect(data["deleted_id"]).to eq(message_2.id)
        expect(data["latest_not_deleted_message_id"]).to eq(message_1.id)
        expect(data["type"]).to eq("delete")
      end
    end
  end

  describe ".publish_refresh!" do
    it "publishes the message" do
      data =
        MessageBus.track_publish { described_class.publish_refresh!(channel, message_1) }[0].data

      expect(data["chat_message"]["id"]).to eq(message_1.id)
      expect(data["type"]).to eq("refresh")
    end
  end

  describe ".publish_user_tracking_state!" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }
    fab!(:user)

    let(:data) do
      MessageBus
        .track_publish { described_class.publish_user_tracking_state!(user, channel, message_1) }
        .first
        .data
    end

    context "when the user has channel membership" do
      fab!(:membership) do
        Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user)
      end

      it "publishes the tracking state with correct counts" do
        expect(data["unread_count"]).to eq(1)
        expect(data["mention_count"]).to eq(0)
      end
    end

    context "when the user has no channel membership" do
      it "publishes the tracking state with zeroed out counts" do
        expect(data["channel_id"]).to eq(channel.id)
        expect(data["last_read_message_id"]).to eq(message_1.id)
        expect(data["thread_id"]).to eq(nil)
        expect(data["unread_count"]).to eq(0)
        expect(data["mention_count"]).to eq(0)
      end
    end

    context "when the channel has threading enabled and the message is a thread reply" do
      fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

      before do
        message_1.update!(thread: thread)
        thread.update_last_message_id!
        channel.update!(threading_enabled: true)
      end

      context "when the user has thread membership" do
        fab!(:membership) { Fabricate(:user_chat_thread_membership, thread: thread, user: user) }

        it "publishes the tracking state with correct counts" do
          expect(data["thread_id"]).to eq(thread.id)
          expect(data["unread_thread_overview"]).to eq(
            { thread.id.to_s => thread.reload.last_message.created_at.iso8601(3) },
          )
          expect(data["thread_tracking"]).to eq(
            {
              "unread_count" => 1,
              "mention_count" => 0,
              "watched_threads_unread_count" => 0,
              "last_reply_created_at" => nil,
            },
          )
        end
      end

      context "when the user has no thread membership" do
        it "publishes the tracking state with zeroed out counts" do
          expect(data["thread_id"]).to eq(thread.id)
          expect(data["unread_thread_overview"]).to eq({})
          expect(data["thread_tracking"]).to eq(
            {
              "unread_count" => 0,
              "mention_count" => 0,
              "watched_threads_unread_count" => 0,
              "last_reply_created_at" => nil,
            },
          )
        end
      end
    end
  end

  describe ".calculate_publish_targets" do
    context "when threading_enabled is false for the channel" do
      before { channel.update!(threading_enabled: false) }

      context "when the message is the original message of a thread" do
        fab!(:thread) { Fabricate(:chat_thread, original_message: message_1, channel: channel) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message_1)
          expect(targets).to contain_exactly("/chat/#{channel.id}")
        end
      end

      context "when the message is a thread reply" do
        fab!(:thread) do
          Fabricate(
            :chat_thread,
            original_message: Fabricate(:chat_message, chat_channel: channel),
            channel: channel,
          )
        end

        before { message_1.update!(thread: thread) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message_1)
          expect(targets).to contain_exactly("/chat/#{channel.id}")
        end
      end

      context "when the message is not part of a thread" do
        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message_1)
          expect(targets).to contain_exactly("/chat/#{channel.id}")
        end
      end
    end

    context "when threading_enabled is true for the channel" do
      before { channel.update!(threading_enabled: true) }

      context "when the message is the original message of a thread" do
        fab!(:thread) { Fabricate(:chat_thread, original_message: message_1, channel: channel) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message_1)
          expect(targets).to contain_exactly(
            "/chat/#{channel.id}",
            "/chat/#{channel.id}/thread/#{thread.id}",
          )
        end
      end

      context "when the message is a thread reply" do
        fab!(:thread) do
          Fabricate(
            :chat_thread,
            original_message: Fabricate(:chat_message, chat_channel: channel),
            channel: channel,
          )
        end

        before { message_1.update!(thread: thread) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message_1)
          expect(targets).to contain_exactly("/chat/#{channel.id}/thread/#{thread.id}")
        end
      end

      context "when the message is not part of a thread" do
        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message_1)
          expect(targets).to contain_exactly("/chat/#{channel.id}")
        end
      end
    end
  end

  describe ".publish_new!" do
    let(:staged_id) { 999 }

    context "when the message is not a thread reply" do
      it "publishes to the new_messages_message_bus_channel" do
        messages =
          MessageBus.track_publish(described_class.new_messages_message_bus_channel(channel.id)) do
            described_class.publish_new!(channel, message_1, staged_id)
          end
        expect(messages.first.data).to eq(
          {
            type: "channel",
            channel_id: channel.id,
            thread_id: nil,
            message:
              Chat::MessageSerializer.new(
                message_1,
                { scope: Guardian.new(nil), root: false },
              ).as_json,
          },
        )
      end

      it "calls MessageBus with the correct permissions" do
        MessageBus.stubs(:publish)
        MessageBus.expects(:publish).with("/chat/#{channel.id}", anything, {})

        described_class.publish_new!(channel, message_1, staged_id)
      end
    end

    context "when the message is a thread reply" do
      fab!(:thread) do
        Fabricate(
          :chat_thread,
          original_message: Fabricate(:chat_message, chat_channel: channel),
          channel: channel,
        )
      end

      before { message_1.update!(thread: thread) }

      context "if threading_enabled is false for the channel" do
        before { channel.update!(threading_enabled: false) }

        it "publishes to the new_messages_message_bus_channel" do
          messages =
            MessageBus.track_publish(
              described_class.new_messages_message_bus_channel(channel.id),
            ) { described_class.publish_new!(channel, message_1, staged_id) }
          expect(messages).not_to be_empty
        end

        it "calls MessageBus with the correct permissions" do
          MessageBus.stubs(:publish)
          MessageBus.expects(:publish).with("/chat/#{channel.id}", anything, {})

          described_class.publish_new!(channel, message_1, staged_id)
        end
      end

      context "if threading_enabled is true for the channel" do
        before { channel.update!(threading_enabled: true) }

        it "does publish to the new_messages_message_bus_channel" do
          messages =
            MessageBus.track_publish(
              described_class.new_messages_message_bus_channel(channel.id),
            ) { described_class.publish_new!(channel, message_1, staged_id) }
          expect(messages.first.data).to eq(
            {
              type: "thread",
              channel_id: channel.id,
              thread_id: thread.id,
              force_thread: false,
              message:
                Chat::MessageSerializer.new(
                  message_1,
                  { scope: Guardian.new(nil), root: false },
                ).as_json,
            },
          )
        end

        it "calls MessageBus with the correct permissions" do
          MessageBus.stubs(:publish)
          MessageBus.expects(:publish).with("/chat/#{channel.id}", anything, {})

          described_class.publish_new!(channel, message_1, staged_id)
        end
      end
    end
  end
end
