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

  describe "#add_lightbox_to_images" do
    fab!(:upload) { Fabricate(:upload, width: 800, height: 600) }

    it "adds lightbox class to quoted images" do
      cooked_html = <<~HTML
      <blockquote>
        <img src="#{upload.url}" width="500" height="300">
      </blockquote>
    HTML

      Chat::Message.stubs(:cook).returns(cooked_html)
      processor = described_class.new(message)

      processor.run!

      doc = processor.instance_variable_get(:@doc)
      img = doc.at_css("img")

      expect(img["class"]).to include("lightbox")
      expect(img["data-large-src"]).to eq(upload.url)
      expect(img["data-target-width"]).to eq("800")
      expect(img["data-target-height"]).to eq("600")
    end
  end
end
