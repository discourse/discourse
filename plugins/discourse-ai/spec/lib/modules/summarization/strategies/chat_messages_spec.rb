# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::Strategies::ChatMessages do
  subject(:chat_messages) { described_class.new(channel, 6) }

  fab!(:channel) { Fabricate(:category_channel, threading_enabled: true) }
  fab!(:original_message) { Fabricate(:chat_message, chat_channel: channel) }
  fab!(:thread) { Fabricate(:chat_thread, channel:, original_message:) }
  fab!(:reply) { Fabricate(:chat_message, chat_channel: channel, thread:) }
  fab!(:other_message) { Fabricate(:chat_message, chat_channel: channel) }

  before { enable_current_plugin }

  describe "#targets_data" do
    it "includes the replies of a thread" do
      expect(chat_messages.targets_data.map { |item| item[:id] }).to contain_exactly(
        original_message.id,
        reply.id,
        other_message.id,
      )
    end

    it "excludes the replies of a thread whose original message was trashed" do
      original_message.trash!

      expect(chat_messages.targets_data.map { |item| item[:id] }).to contain_exactly(
        other_message.id,
      )
    end
  end
end
