# frozen_string_literal: true

RSpec.describe Chat::ChatMessageProcessor do
  fab!(:message) { Fabricate(:chat_message) }

  it "cooks using the last_editor_id of the message" do
    ChatMessage.expects(:cook).with(message.message, user_id: message.last_editor_id)
    described_class.new(message)
  end
end
