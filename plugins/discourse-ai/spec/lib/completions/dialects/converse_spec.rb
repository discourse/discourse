# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::Converse do
  fab!(:model, :bedrock_converse_model)

  before { enable_current_plugin }

  describe "#translate" do
    it "embeds participant names in user message content" do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          nil,
          messages: [{ type: :user, id: "admin", content: "Who am I?" }],
        )

      translated = described_class.new(prompt, model).translate

      expect(translated.messages).to eq([{ role: "user", content: [{ text: "admin: Who am I?" }] }])
    end

    it "records a skip for a document it cannot render as text" do
      model.update!(allowed_attachment_types: ["pdf"])
      prompt =
        DiscourseAi::Completions::Prompt.new(
          nil,
          messages: [{ type: :user, content: ["Read this: ", { upload_id: 123 }] }],
        )
      prompt.upload_skips = []

      allow(DiscourseAi::Completions::UploadEncoder).to receive(:encode).and_return(
        [{ kind: :document, filename: "report.pdf", mime_type: "application/pdf", base64: "eA==" }],
      )

      translated = described_class.new(prompt, model).translate

      expect(translated.messages).to eq([{ role: "user", content: [{ text: "Read this: " }] }])
      expect(prompt.upload_skips).to eq(
        [{ upload_id: 123, filename: "report.pdf", message: "not accepted by this model" }],
      )
    end

    it "keeps participant names with text that follows an image" do
      model.update!(vision_enabled: true)
      prompt =
        DiscourseAi::Completions::Prompt.new(
          nil,
          messages: [
            { type: :user, id: "admin", content: [{ upload_id: 123 }, "Describe this image"] },
          ],
        )

      allow(DiscourseAi::Completions::UploadEncoder).to receive(:encode).and_return(
        [{ kind: :image, mime_type: "image/png", base64: Base64.strict_encode64("image") }],
      )

      translated = described_class.new(prompt, model).translate

      expect(translated.messages.first[:content]).to eq(
        [
          { image: { format: "png", source: { bytes: "image" } } },
          { text: "admin: Describe this image" },
        ],
      )
    end

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
