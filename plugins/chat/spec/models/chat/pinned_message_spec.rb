# frozen_string_literal: true

RSpec.describe Chat::PinnedMessage do
  describe "associations" do
    it { is_expected.to belong_to(:chat_message).class_name("Chat::Message") }
    it { is_expected.to belong_to(:chat_channel).class_name("Chat::Channel") }
    it { is_expected.to belong_to(:user).with_foreign_key(:pinned_by_id) }
  end

  describe "validations" do
    subject { Fabricate(:chat_pinned_message) }

    it { is_expected.to validate_uniqueness_of(:chat_message_id) }
  end

  describe ".for_channel" do
    fab!(:channel, :chat_channel)
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel) }
    fab!(:other_channel, :chat_channel)
    fab!(:other_message) { Fabricate(:chat_message, chat_channel: other_channel) }

    before do
      Fabricate(:chat_pinned_message, chat_message: message_1, chat_channel: channel)
      Fabricate(:chat_pinned_message, chat_message: message_2, chat_channel: channel)
      Fabricate(:chat_pinned_message, chat_message: other_message, chat_channel: other_channel)
    end

    it "returns pins for the specified channel" do
      pins = described_class.for_channel(channel)
      expect(pins.map(&:chat_message_id)).to contain_exactly(message_1.id, message_2.id)
    end
  end

  describe ".excluding_deleted_threads" do
    fab!(:threading_channel) { Fabricate(:category_channel, threading_enabled: true) }
    fab!(:original_message) { Fabricate(:chat_message, chat_channel: threading_channel) }
    fab!(:thread) do
      Fabricate(:chat_thread, channel: threading_channel, original_message: original_message)
    end
    fab!(:reply) { Fabricate(:chat_message, chat_channel: threading_channel, thread: thread) }
    fab!(:pin) do
      Fabricate(:chat_pinned_message, chat_message: reply, chat_channel: threading_channel)
    end

    it "keeps the pin while the original message is visible" do
      expect(described_class.excluding_deleted_threads).to include(pin)
    end

    it "excludes the pin when the original message is trashed" do
      original_message.trash!

      expect(described_class.excluding_deleted_threads).not_to include(pin)
    end

    it "excludes the pin when the original message was purged" do
      original_message.destroy!

      expect(described_class.excluding_deleted_threads).not_to include(pin)
    end

    it "keeps the pin for a reply in a channel without threading" do
      threading_channel.update!(threading_enabled: false)
      original_message.trash!

      expect(described_class.excluding_deleted_threads).to include(pin)
    end
  end
end
