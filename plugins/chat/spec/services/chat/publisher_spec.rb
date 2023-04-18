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
    context "when the chat message is the original message of a thread" do
      fab!(:thread) { Fabricate(:chat_thread, original_message: message, channel: channel) }

      it "generates the correct targets" do
        targets = described_class.calculate_publish_targets(channel, message)
        expect(targets).to contain_exactly(
          "/chat/#{channel.id}",
          "/chat/#{channel.id}/thread/#{thread.id}",
        )
      end
    end

    context "when the chat message is a thread reply" do
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

    context "when the chat message is not part of a thread" do
      it "generates the correct targets" do
        targets = described_class.calculate_publish_targets(channel, message)
        expect(targets).to contain_exactly("/chat/#{channel.id}")
      end
    end
  end
end
