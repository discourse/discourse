# frozen_string_literal: true

RSpec.describe Chat::MessageProcessor do
  fab!(:message) { Fabricate(:chat_message) }

  it "cooks using the last_editor_id of the message" do
    Chat::Message.expects(:cook).with(message.message, user_id: message.last_editor_id)
    described_class.new(message)
  end
end
