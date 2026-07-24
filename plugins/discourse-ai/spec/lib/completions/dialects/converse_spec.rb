# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::Converse do
  fab!(:model, :bedrock_converse_model)

  before { enable_current_plugin }

  describe "#translate" do
    it "renders converted document uploads as text content blocks" do
      model.update!(allowed_attachment_types: ["docx"])
      converted_text = "Uploaded document: sample.docx (13 Bytes)\n\nConverted text"
      prompt =
        DiscourseAi::Completions::Prompt.new(
          nil,
          messages: [{ type: :user, content: ["Read this: ", { upload_id: 123 }] }],
        )

      allow(DiscourseAi::Completions::UploadEncoder).to receive(:encode).and_return(
        [
          {
            kind: :document,
            filename: "sample.docx",
            mime_type: "text/plain",
            text: converted_text,
            converted_from: "docx",
          },
        ],
      )

      translated = described_class.new(prompt, model).translate
      user_message = translated.messages.find { |msg| msg[:role] == "user" }

      expect(user_message[:content]).to eq([{ text: "Read this: " }, { text: converted_text }])
    end

    it "skips raw document uploads because Converse raw document support is not enabled" do
      model.update!(allowed_attachment_types: ["doc"])
      prompt =
        DiscourseAi::Completions::Prompt.new(
          nil,
          messages: [{ type: :user, content: ["Read this: ", { upload_id: 123 }] }],
        )

      allow(DiscourseAi::Completions::UploadEncoder).to receive(:encode).and_return(
        [
          {
            kind: :document,
            filename: "sample.doc",
            mime_type: "application/msword",
            base64: "cmF3IGRvYw==",
          },
        ],
      )

      translated = described_class.new(prompt, model).translate
      user_message = translated.messages.find { |msg| msg[:role] == "user" }

      expect(user_message[:content]).to eq([{ text: "Read this: " }])
      expect(user_message[:content]).not_to include(hash_including(image: anything))
      expect(user_message[:content]).not_to include(hash_including(document: anything))
    end

    it "passes raw bytes for image uploads, not the base64-encoded string" do
      model.update!(vision_enabled: true)
      raw_bytes = "\x89PNG\r\n\x1a\nbinary".b
      prompt =
        DiscourseAi::Completions::Prompt.new(
          nil,
          messages: [{ type: :user, content: ["Describe: ", { upload_id: 456 }] }],
        )

      allow(DiscourseAi::Completions::UploadEncoder).to receive(:encode).and_return(
        [{ kind: :image, mime_type: "image/png", base64: Base64.strict_encode64(raw_bytes) }],
      )

      translated = described_class.new(prompt, model).translate
      user_message = translated.messages.find { |msg| msg[:role] == "user" }
      image_block = user_message[:content].find { |c| c[:image] }

      expect(image_block).to be_present
      expect(image_block.dig(:image, :format)).to eq("png")
      # AWS SDK for Ruby expects raw bytes; it will base64-encode on the wire.
      # Passing the base64 string would cause double-encoding and Bedrock would
      # return "Could not process image".
      expect(image_block.dig(:image, :source, :bytes)).to eq(raw_bytes)
    end
  end
end
