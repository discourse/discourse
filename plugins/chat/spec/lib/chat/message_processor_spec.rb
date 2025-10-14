# frozen_string_literal: true

RSpec.describe Chat::MessageProcessor do
  fab!(:message, :chat_message)

  it "cooks using the last_editor_id of the message" do
    Chat::Message.expects(:cook).with(message.message, user_id: message.last_editor_id)
    described_class.new(message)
  end

  describe "#run!" do
    it "processes messages with hotlinked images in oneboxes without errors" do
      # Create a message with an image in a onebox (common when posting URLs with images)
      cooked_html = <<~HTML
        <aside class="onebox">
          <img src="https://example.com/image.jpg" width="500" height="300">
        </aside>
      HTML

      Chat::Message.stubs(:cook).returns(cooked_html)
      processor = described_class.new(message)

      # This should not raise an error even though @post is nil
      expect { processor.run! }.not_to raise_error
    end
  end
end
