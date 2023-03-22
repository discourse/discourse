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
end
