# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Prompt do
  subject(:prompt) { described_class.new(system_insts) }

  let(:system_insts) { "These are the system instructions." }
  let(:user_msg) { "Write something nice" }
  let(:username) { "username1" }
  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:pdf_upload) do
    SiteSetting.authorized_extensions = "*"
    file = Tempfile.new(%w[test-pdf .pdf])
    file.binmode
    file.write(<<~PDF)
        %PDF-1.4
        1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj
        2 0 obj<< /Type /Pages /Count 1 /Kids [3 0 R] >>endobj
        3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>endobj
        4 0 obj<< /Length 44 >>stream
        BT /F1 12 Tf 72 720 Td (Hello PDF) Tj ET
        endstream
        endobj
        xref
        0 5
        0000000000 65535 f
        0000000010 00000 n
        0000000060 00000 n
        0000000111 00000 n
        0000000200 00000 n
        trailer<< /Size 5 /Root 1 0 R >>
        startxref
        268
        %%EOF
      PDF
    file.rewind
    UploadCreator.new(file, "document.pdf").create_for(Discourse.system_user.id)
  ensure
    file.close! if file
  end

  before { enable_current_plugin }

  describe ".new" do
    it "raises for invalid attributes" do
      expect { described_class.new("a bot", messages: {}) }.to raise_error(ArgumentError)
      expect { described_class.new("a bot", tools: {}) }.to raise_error(ArgumentError)

      bad_messages = [{ type: :user, content: "a system message", unknown_attribute: :random }]
      expect { described_class.new("a bot", messages: bad_messages) }.to raise_error(ArgumentError)

      bad_messages2 = [{ type: :user }]
      expect { described_class.new("a bot", messages: bad_messages2) }.to raise_error(ArgumentError)

      bad_messages3 = [{ content: "some content associated to no one" }]
      expect { described_class.new("a bot", messages: bad_messages3) }.to raise_error(ArgumentError)
    end
  end

  describe "image support" do
    it "allows adding uploads inline in messages" do
      upload = UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)

      prompt.max_pixels = 300
      prompt.push(
        type: :user,
        content: ["this is an image", { upload_id: upload.id }, "this was an image"],
      )

      encoded = prompt.content_with_encoded_uploads(prompt.messages.last[:content])

      expect(encoded.length).to eq(3)
      expect(encoded[0]).to eq("this is an image")
      expect(encoded[1][:mime_type]).to eq("image/jpeg")
      expect(encoded[2]).to eq("this was an image")
    end

    it "only encodes documents when explicitly allowed" do
      prompt.push(type: :user, content: ["this is a pdf", { upload_id: pdf_upload.id }])

      expect(prompt.encoded_uploads(prompt.messages.last)).to be_empty

      encoded = prompt.encoded_uploads(prompt.messages.last, allow_documents: true)

      expect(encoded.length).to eq(1)
      expect(encoded.first[:mime_type]).to eq("application/pdf")
      expect(encoded.first[:kind]).to eq(:document)
    end
  end

  describe "#push" do
    describe "turn validations" do
      it "validates that tool messages have a previous tool_call message" do
        prompt.push(type: :user, content: user_msg, id: username)
        prompt.push(type: :model, content: "I'm a model msg")

        expect { prompt.push(type: :tool, content: "I'm the tool call results") }.to raise_error(
          DiscourseAi::Completions::Prompt::INVALID_TURN,
        )
      end

      it "validates that model messages have either a previous tool or user messages" do
        prompt.push(type: :user, content: user_msg, id: username)
        prompt.push(type: :model, content: "I'm a model msg")

        expect { prompt.push(type: :model, content: "I'm a second model msg") }.to raise_error(
          DiscourseAi::Completions::Prompt::INVALID_TURN,
        )
      end
    end

    it "system message is always first" do
      prompt.push(type: :user, content: user_msg, id: username)

      system_message = prompt.messages.first

      expect(system_message[:type]).to eq(:system)
      expect(system_message[:content]).to eq(system_insts)
    end

    it "includes the pushed message" do
      prompt.push(type: :user, content: user_msg, id: username)

      system_message = prompt.messages.last

      expect(system_message[:type]).to eq(:user)
      expect(system_message[:content]).to eq(user_msg)
      expect(system_message[:id]).to eq(username)
    end
  end

  describe "#push_model_response" do
    it "buffers streamed string chunks into a single model message" do
      prompt.push(type: :user, content: user_msg, id: username)

      prompt.push_model_response(["Hello", " ", "World"])

      expect(prompt.messages.last).to include(type: :model, content: "Hello World")
    end

    it "buffers thinking until the next assistant message arrives" do
      prompt.push(type: :user, content: user_msg, id: username)

      thinking =
        DiscourseAi::Completions::Thinking.new(
          message: "summary",
          partial: false,
          provider_info: {
            open_ai_responses: {
              reasoning_id: "rs_1",
              encrypted_content: "ENC",
            },
          },
        )

      prompt.push_model_response(thinking)

      expect(prompt.messages.last).to include(type: :user)
      expect(prompt.messages.last).not_to have_key(:thinking)
      expect(prompt.messages.last).not_to have_key(:thinking_provider_info)

      prompt.push_model_response("Hello")

      expect(prompt.messages.last).to include(type: :model, content: "Hello", thinking: "summary")
      expect(prompt.messages.last[:thinking_provider_info]).to include(
        open_ai_responses: include(reasoning_id: "rs_1", encrypted_content: "ENC"),
      )
    end

    it "appends additional streamed text to the existing model message" do
      prompt.push(type: :user, content: user_msg, id: username)

      prompt.push_model_response("Hello")
      prompt.push_model_response(" World")

      model_messages = prompt.messages.select { |m| m[:type] == :model }
      expect(model_messages.length).to eq(1)
      expect(model_messages.first[:content]).to eq("Hello World")
    end

    it "attaches thinking metadata to the tool call message" do
      prompt.push(type: :user, content: user_msg, id: username)

      prompt.push_model_response(
        [
          DiscourseAi::Completions::Thinking.new(
            message: "summary",
            provider_info: {
              open_ai_responses: {
                reasoning_id: "rs_1",
                encrypted_content: "ENC",
              },
            },
          ),
          DiscourseAi::Completions::ToolCall.new(
            id: "call_1",
            name: "echo",
            parameters: {
              string: "hello",
            },
          ),
        ],
      )

      expect(prompt.messages.last).to include(type: :tool_call, thinking: "summary")
      expect(prompt.messages.last[:thinking_provider_info]).to include(
        open_ai_responses: include(reasoning_id: "rs_1", encrypted_content: "ENC"),
      )
    end
  end
end
