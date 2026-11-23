# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Prompt do
  subject(:prompt) { described_class.new(system_insts) }

  let(:system_insts) { "These are the system instructions." }
  let(:user_msg) { "Write something nice" }
  let(:username) { "username1" }
  let(:system_message) { { type: :system, content: system_insts } }
  let(:user_message) { { type: :user, content: user_msg, id: username } }
  let(:tool_call_message) do
    {
      type: :tool_call,
      id: "search-1",
      name: "search",
      content: { arguments: { query: "private query" } }.to_json,
    }
  end
  let(:tool_result_message) do
    { type: :tool, id: "search-1", name: "search", content: "Search results" }
  end
  let(:signed_reply) do
    {
      type: :model,
      content: ["Earlier reply", { upload_id: 11 }],
      thinking_provider_info: {
        open_ai_responses: {
          encrypted_content: "earlier-signature",
        },
      },
    }
  end
  let(:orphan_tool_result) do
    {
      type: :tool,
      id: "orphan-result",
      name: "search",
      content: [
        "Private output",
        { encoded_upload: { kind: :image, mime_type: "image/png", base64: "aW1hZ2U=" } },
        "Caption",
      ],
      thinking: "Private reasoning",
      provider_data: {
        thought_signature: "private-signature",
      },
    }
  end
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
    it "keeps parallel results in arrival order without treating a stored system turn as instructions" do
      second_call = tool_call_message.merge(id: "search-2")
      second_result = tool_result_message.merge(id: second_call[:id], content: "Second result")
      late_system = { type: :system, content: "Replacement instructions" }
      messages = [
        user_message,
        tool_call_message,
        second_call,
        late_system,
        second_result,
        tool_result_message,
      ]

      recovered = described_class.new(system_insts, messages: messages)

      expect(recovered.system_message_text).to eq(system_insts)
      expect(recovered.messages).to eq(
        [
          system_message,
          user_message,
          tool_call_message,
          second_call,
          second_result,
          tool_result_message,
        ],
      )
    end

    it "preserves legacy tool calls and results paired by name" do
      messages = [user_message, tool_call_message.except(:id), tool_result_message.except(:id)]

      expect(described_class.new(messages: messages).messages).to eq(messages)
    end

    it "separates consecutive signed replies and replays them without extra separators" do
      later_reply = {
        type: :model,
        content: ["Later reply", { upload_id: 22 }],
        provider_data: {
          thought_signature: "later-signature",
        },
      }
      recovered = described_class.new(system_insts, messages: [signed_reply, later_reply])
      expected = [
        system_message,
        described_class::HISTORY_PREAMBLE,
        signed_reply,
        described_class::ASSISTANT_CONTINUATION,
        later_reply,
      ]

      expect(recovered.messages).to eq(expected)
      expect(described_class.new(messages: recovered.messages).messages).to eq(expected)
    end

    it "keeps a mismatched tool exchange as evidence without moving the next request's saved boundary" do
      next_request = { type: :user, content: "Next request" }
      messages = [user_message, tool_call_message, orphan_tool_result, next_request]
      recovered = described_class.new(system_insts, messages: messages)

      expect(recovered.messages.map { |message| message[:type] }).to eq(
        %i[system user model user model user],
      )
      expect(recovered.messages[2][:content]).to include(tool_call_message[:content])
      expect(recovered.messages[4][:content].drop(1)).to eq(orphan_tool_result[:content])
      expect(recovered.messages[recovered.normalized_message_offset(4)]).to eq(next_request)
      expect(recovered.normalized_message_offset(5)).to eq(recovered.messages.size)
    end

    it "rejects invalid attributes, roles and content rather than repairing them" do
      expect { described_class.new(messages: {}) }.to raise_error(ArgumentError)
      expect { described_class.new(tools: {}) }.to raise_error(ArgumentError)
      [
        { type: :user, content: user_msg, unknown_attribute: true },
        { type: :user },
        { content: user_msg },
        { type: :unknown, content: user_msg },
        { type: :model, content: 42 },
        { type: :tool, content: [{ unsupported_part: true }] },
      ].each do |message|
        expect { described_class.new(messages: [message]) }.to raise_error(ArgumentError)
      end
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

    it "filters pre-encoded uploads by the allowed kinds" do
      encoded_image = { kind: :image, mime_type: "image/png", base64: "aW1hZ2U=" }
      encoded_document = { kind: :document, mime_type: "application/pdf", base64: "ZG9jdW1lbnQ=" }
      content = ["uploads", { encoded_upload: encoded_image }, { encoded_upload: encoded_document }]

      expect(
        prompt.content_with_encoded_uploads(content, allow_images: false, allow_documents: true),
      ).to eq(["uploads", nil, encoded_document])
    end

    it "rejects malformed pre-encoded uploads" do
      expect do
        prompt.push(type: :user, content: [{ encoded_upload: { kind: :image } }])
      end.to raise_error(ArgumentError, /Array message content/)
    end

    it "only encodes documents when explicitly allowed" do
      prompt.push(type: :user, content: ["this is a pdf", { upload_id: pdf_upload.id }])

      expect(prompt.encoded_uploads(prompt.messages.last)).to be_empty

      encoded = prompt.encoded_uploads(prompt.messages.last, allow_documents: true)

      expect(encoded.length).to eq(1)
      expect(encoded.first[:mime_type]).to eq("application/pdf")
      expect(encoded.first[:kind]).to eq(:document)
    end

    it "can encode documents without encoding images" do
      image_upload =
        UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
      prompt.push(
        type: :user,
        content: ["mixed uploads", { upload_id: image_upload.id }, { upload_id: pdf_upload.id }],
      )

      encoded =
        prompt.encoded_uploads(prompt.messages.last, allow_images: false, allow_documents: true)

      expect(encoded.length).to eq(1)
      expect(encoded.first[:kind]).to eq(:document)
      expect(encoded.first[:filename]).to eq("document.pdf")
    end
  end

  describe "#push" do
    it "keeps a live call while waiting and turns a duplicate result into evidence" do
      prompt.push(**user_message)
      prompt.push(**tool_call_message)
      expect(prompt.messages.last).to eq(tool_call_message)

      prompt.push(type: :system, content: "Replacement instructions")
      prompt.push(**tool_result_message)
      duplicate = tool_result_message.merge(content: "Duplicate output")
      prompt.push(**duplicate)

      expect(prompt.messages[0...-1]).to eq(
        [system_message, user_message, tool_call_message, tool_result_message],
      )
      expect(prompt.messages.last).to match(
        type: :model,
        content: [
          a_string_starting_with("Incomplete historical tool evidence"),
          duplicate[:content],
        ],
      )
    end

    it "retains an orphan result and its attachment without exposing private metadata in evidence or logs" do
      prompt.push(**user_message)
      prompt.push(**signed_reply)

      logs = track_log_messages { prompt.push(**orphan_tool_result) }

      evidence = prompt.messages.last
      expect(prompt.messages[0...-1]).to eq(
        [system_message, user_message, signed_reply, described_class::ASSISTANT_CONTINUATION],
      )
      expect(evidence).to match(
        type: :model,
        content: [
          a_string_starting_with("Incomplete historical tool evidence (not executable):"),
          *orphan_tool_result[:content],
        ],
      )
      body, attachment, caption = orphan_tool_result[:content]
      private_metadata = [
        orphan_tool_result[:thinking],
        orphan_tool_result.dig(:provider_data, :thought_signature),
      ]
      expect(described_class.text_only(evidence)).not_to include(*private_metadata)
      expect(logs.warnings.join).to include(
        "stage=push index=3 previous=model next=tool reason=orphan_tool_result",
      )
      expect(logs.warnings.join).not_to include(
        body,
        caption,
        attachment.dig(:encoded_upload, :base64),
        orphan_tool_result[:id],
        *private_metadata,
      )
    end

    it "turns an unfinished parallel batch into evidence when the next user request arrives" do
      next_request = { type: :user, content: "Next request" }
      pending_call =
        tool_call_message.merge(id: "search-2", content: '{"arguments":{"query":"other"}}')
      batch = [tool_call_message, pending_call, tool_result_message]
      [user_message, signed_reply, *batch].each { |message| prompt.push(**message) }

      prompt.push(**next_request)

      expect(prompt.messages.pluck(:type)).not_to include(:tool, :tool_call)
      replies = prompt.messages.select { |message| message[:type] == :model }
      expect(replies.first).to eq(signed_reply)
      expect(replies.drop(1).map { |message| message[:content].last }).to eq(batch.pluck(:content))
      expect(prompt.messages.last).to eq(next_request)
      expect(described_class.new(messages: prompt.messages).messages).to eq(prompt.messages)
    end

    it "pairs against the current prompt after its messages are replaced" do
      prompt.push(**user_message)
      prompt.push(**tool_call_message)
      replacement_call = tool_call_message.merge(id: "replacement")
      replacement_result = tool_result_message.merge(id: "replacement")
      prompt.messages.replace([system_message, user_message, replacement_call])

      prompt.push(**replacement_result)

      expect(prompt.messages).to eq(
        [system_message, user_message, replacement_call, replacement_result],
      )
    end

    it "accepts a first user message on an empty prompt" do
      empty_prompt = described_class.new

      empty_prompt.push(**user_message)

      expect(empty_prompt.messages).to eq([user_message])
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
    it "keeps streamed answer chunks separate from orphan tool evidence" do
      prompt.push(**user_message)
      result =
        DiscourseAi::Completions::ToolResult.new(
          content: orphan_tool_result[:content],
          tool_call:
            DiscourseAi::Completions::ToolCall.new(id: orphan_tool_result[:id], name: "search"),
        )

      prompt.push_model_response([result, "Final", " answer"])

      expect(prompt.messages[2][:content].drop(1)).to eq(orphan_tool_result[:content])
      expect(prompt.messages.last(2)).to eq(
        [described_class::ASSISTANT_CONTINUATION, { type: :model, content: "Final answer" }],
      )
    end

    it "buffers streamed string chunks into a single model message" do
      prompt.push(type: :user, content: user_msg, id: username)
      prompt.push_model_response(["Hello", " ", "World"])
      expect(prompt.messages.last).to include(type: :model, content: "Hello World")
    end

    it "attaches thinking to next response" do
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

      prompt.push_model_response([thinking, "Hello"])

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

    it "attaches trailing thinking to the previous response" do
      prompt.push(type: :user, content: user_msg, id: username)

      thinking =
        DiscourseAi::Completions::Thinking.new(
          message: nil,
          partial: false,
          provider_info: {
            gemini: {
              thought_signature_parts: [{ text: "", thoughtSignature: "sig-123" }],
            },
          },
        )

      prompt.push_model_response(["Hello", thinking])

      expect(prompt.messages.last).to include(type: :model, content: "Hello")
      expect(prompt.messages.last[:thinking_provider_info]).to include(
        gemini: include(thought_signature_parts: [{ text: "", thoughtSignature: "sig-123" }]),
      )
    end

    it "merges consecutive thinking before attaching it to the response" do
      prompt.push(type: :user, content: user_msg, id: username)

      prompt.push_model_response(
        [
          DiscourseAi::Completions::Thinking.new(
            message: "first",
            provider_info: {
              gemini: {
                thought_signature_parts: [{ text: "", thoughtSignature: "sig-1" }],
              },
            },
          ),
          DiscourseAi::Completions::Thinking.new(
            message: "second",
            provider_info: {
              gemini: {
                grounding_metadata: {
                  webSearchQueries: ["query"],
                },
              },
            },
          ),
          "Hello",
        ],
      )

      expect(prompt.messages.last[:thinking]).to eq("first\n\nsecond")
      expect(prompt.messages.last[:thinking_provider_info]).to include(
        gemini:
          include(
            thought_signature_parts: [{ text: "", thoughtSignature: "sig-1" }],
            grounding_metadata: {
              webSearchQueries: ["query"],
            },
          ),
      )
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
