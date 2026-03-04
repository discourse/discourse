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

    it "returns pins for the specified channel ordered by created_at desc" do
      pins = described_class.for_channel(channel)
      expect(pins.count).to eq(2)
      expect(pins.map(&:chat_message_id)).to contain_exactly(message_1.id, message_2.id)
    end
  end
end
