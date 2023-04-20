# frozen_string_literal: true

require "rails_helper"

describe Chat::Publisher do
  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }

  describe ".publish_refresh!" do
    it "publishes the message" do
      data = MessageBus.track_publish { described_class.publish_refresh!(channel, message) }[0].data

      expect(data["chat_message"]["id"]).to eq(message.id)
      expect(data["type"]).to eq("refresh")
    end
  end

  describe ".calculate_publish_targets" do
    context "when enable_experimental_chat_threaded_discussions is false" do
      before { SiteSetting.enable_experimental_chat_threaded_discussions = false }

      context "when the message is the original message of a thread" do
        fab!(:thread) { Fabricate(:chat_thread, original_message: message, channel: channel) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message)
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

        before { message.update!(thread: thread) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message)
          expect(targets).to contain_exactly("/chat/#{channel.id}")
        end
      end

      context "when the message is not part of a thread" do
        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message)
          expect(targets).to contain_exactly("/chat/#{channel.id}")
        end
      end
    end

    context "when threading_enabled is false for the channel" do
      before do
        SiteSetting.enable_experimental_chat_threaded_discussions = true
        channel.update!(threading_enabled: false)
      end

      context "when the message is the original message of a thread" do
        fab!(:thread) { Fabricate(:chat_thread, original_message: message, channel: channel) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message)
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

        before { message.update!(thread: thread) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message)
          expect(targets).to contain_exactly("/chat/#{channel.id}")
        end
      end

      context "when the message is not part of a thread" do
        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message)
          expect(targets).to contain_exactly("/chat/#{channel.id}")
        end
      end
    end

    context "when enable_experimental_chat_threaded_discussions is true and threading_enabled is true for the channel" do
      before do
        channel.update!(threading_enabled: true)
        SiteSetting.enable_experimental_chat_threaded_discussions = true
      end

      context "when the message is the original message of a thread" do
        fab!(:thread) { Fabricate(:chat_thread, original_message: message, channel: channel) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message)
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

        before { message.update!(thread: thread) }

        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message)
          expect(targets).to contain_exactly("/chat/#{channel.id}/thread/#{thread.id}")
        end
      end

      context "when the message is not part of a thread" do
        it "generates the correct targets" do
          targets = described_class.calculate_publish_targets(channel, message)
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
            described_class.publish_new!(channel, message, staged_id)
          end
        expect(messages.first.data).to eq(
          {
            channel_id: channel.id,
            message_id: message.id,
            user_id: message.user_id,
            username: message.user.username,
            thread_id: nil,
          },
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

      before { message.update!(thread: thread) }

      context "if enable_experimental_chat_threaded_discussions is false" do
        before { SiteSetting.enable_experimental_chat_threaded_discussions = false }

        it "publishes to the new_messages_message_bus_channel" do
          messages =
            MessageBus.track_publish(
              described_class.new_messages_message_bus_channel(channel.id),
            ) { described_class.publish_new!(channel, message, staged_id) }
          expect(messages).not_to be_empty
        end
      end

      context "if enable_experimental_chat_threaded_discussions is true" do
        before { SiteSetting.enable_experimental_chat_threaded_discussions = true }

        context "if threading_enabled is false for the channel" do
          before { channel.update!(threading_enabled: false) }

          it "publishes to the new_messages_message_bus_channel" do
            messages =
              MessageBus.track_publish(
                described_class.new_messages_message_bus_channel(channel.id),
              ) { described_class.publish_new!(channel, message, staged_id) }
            expect(messages).not_to be_empty
          end
        end

        context "if threading_enabled is true for the channel" do
          before { channel.update!(threading_enabled: true) }

          it "does not publish to the new_messages_message_bus_channel" do
            messages =
              MessageBus.track_publish(
                described_class.new_messages_message_bus_channel(channel.id),
              ) { described_class.publish_new!(channel, message, staged_id) }
            expect(messages).to be_empty
          end
        end
      end
    end
  end
end
