# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::Gemini do
  fab!(:user)
  fab!(:model) { Fabricate(:gemini_model, vision_enabled: true) }

  before { enable_current_plugin }

  let(:llm) { DiscourseAi::Completions::Llm.proxy(model) }

  let(:echo_tool_definition) do
    DiscourseAi::Completions::ToolDefinition.from_hash(
      name: "echo",
      description: "echo something",
      parameters: [{ name: "text", type: "string", description: "text to echo", required: true }],
    )
  end

  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:upload100x100) do
    UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
  end

  def with_scripted_responses(responses, llm_model: model, &block)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      responses,
      llm: llm_model,
      transport: :scripted_http,
      &block
    )
  end

  def gemini_chunk(parts:, finish_reason: nil, usage: nil)
    chunk = {
      candidates: [{ content: { parts: parts, role: "model" }, index: 0 }],
      modelVersion: "gemini-1.5-pro-002",
    }

    chunk[:candidates][0][:finishReason] = finish_reason if finish_reason
    chunk[:usageMetadata] = usage if usage
    chunk
  end

  def sse_chunks(chunks)
    chunks.map { |chunk| "data: #{chunk.to_json}\n\n" }
  end

  it "correctly configures thinking when enabled" do
    model.update!(provider_params: { enable_thinking: "true", thinking_tokens: "10000" })

    with_scripted_responses(["Using thinking mode"]) do |scripted_http|
      llm.generate("Hello", user: user)

      body = scripted_http.last_request
      expect(body.dig("generationConfig", "thinkingConfig")).to eq("thinkingBudget" => 10_000)
    end
  end

  it "correctly handles max output tokens" do
    model.update!(max_output_tokens: 1000)

    with_scripted_responses(["some response", "some response", "some response"]) do |scripted_http|
      llm.generate("Hello", user: user, max_tokens: 10_000)
      expect(scripted_http.last_request.dig("generationConfig", "maxOutputTokens")).to eq(1000)

      llm.generate("Hello", user: user, max_tokens: 50)
      expect(scripted_http.last_request.dig("generationConfig", "maxOutputTokens")).to eq(50)

      llm.generate("Hello", user: user)
      expect(scripted_http.last_request.dig("generationConfig", "maxOutputTokens")).to eq(1000)
    end
  end

  it "clamps thinking tokens within allowed limits" do
    model.update!(provider_params: { enable_thinking: "true", thinking_tokens: "30000" })

    with_scripted_responses(["Thinking tokens clamped"]) do |scripted_http|
      llm.generate("Hello", user: user)

      expect(scripted_http.last_request.dig("generationConfig", "thinkingConfig")).to eq(
        "thinkingBudget" => 24_576,
      )
    end
  end

  it "does not add thinking config when disabled" do
    model.update!(provider_params: { enable_thinking: false, thinking_tokens: "10000" })

    with_scripted_responses(["No thinking mode"]) do |scripted_http|
      llm.generate("Hello", user: user)

      expect(scripted_http.last_request.dig("generationConfig", "thinkingConfig")).to be_nil
    end
  end

  it "explicitly specifies tool config" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool_definition])

    with_scripted_responses(["World"]) do |scripted_http|
      expect(llm.generate(prompt, user: user)).to eq("World")

      expect(scripted_http.last_request["tool_config"]).to eq(
        "function_calling_config" => {
          "mode" => "AUTO",
        },
      )
    end
  end

  it "properly encodes tool calls" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool_definition])

    with_scripted_responses(
      [{ tool_calls: [{ name: "echo", arguments: { text: "<S>ydney" } }] }],
    ) do
      tool_call = llm.generate(prompt, user: user)

      expected =
        DiscourseAi::Completions::ToolCall.new(
          id: "tool_0",
          name: "echo",
          parameters: {
            text: "<S>ydney",
          },
        )

      expect(tool_call).to eq(expected)
    end
  end

  it "supports Vision API" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are image bot",
        messages: [
          { type: :user, id: "user1", content: ["hello", { upload_id: upload100x100.id }] },
        ],
      )

    encoded = prompt.encode_upload(upload100x100.id)

    with_scripted_responses(["World"]) do |scripted_http|
      expect(llm.generate(prompt, user: user)).to eq("World")

      body = scripted_http.last_request
      expect(body.dig("systemInstruction", "parts")).to eq([{ "text" => "You are image bot" }])

      parts = body.dig("contents", 0, "parts")
      expect(parts).to include({ "text" => "user1: hello" })
      expect(parts).to include(
        { "inlineData" => { "mimeType" => encoded[:mime_type], "data" => encoded[:base64] } },
      )
    end
  end

  it "can stream tool calls correctly" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool_definition])
    usage = { promptTokenCount: 625, candidatesTokenCount: 4, totalTokenCount: 629 }

    with_scripted_responses(
      [{ tool_calls: [{ name: "echo", arguments: { text: "sam<>wh!s" } }], usage: usage }],
    ) do
      output = []
      llm.generate(prompt, user: user) { |partial| output << partial }

      expected =
        DiscourseAi::Completions::ToolCall.new(
          id: "tool_0",
          name: "echo",
          parameters: {
            text: "sam<>wh!s",
          },
        )

      expect(output).to eq([expected])

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(625)
      expect(log.response_tokens).to eq(4)
    end
  end

  it "can correctly handle malformed responses" do
    response = <<~TEXT
      data: {"candidates": [{"content": {"parts": [{"text": "Certainly"}],"role": "model"}}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

      data: {"candidates": [{"content": {"parts": [{"text": "! I'll create a simple \\"Hello, World!\\" page where each letter"}],"role": "model"},"safetyRatings": [{"category": "HARM_CATEGORY_HATE_SPEECH","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HARASSMENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT","probability": "NEGLIGIBLE"}]}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

      data: {"candidates": [{"content": {"parts": [{"text": " has a different color using inline styles for simplicity.  Each letter will be wrapped"}],"role": "model"},"safetyRatings": [{"category": "HARM_CATEGORY_HATE_SPEECH","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HARASSMENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT","probability": "NEGLIGIBLE"}]}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

      data: {"candidates": [{"content": {"parts": [{"text": ""}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

      data: {"candidates": [{"finishReason": "MALFORMED_FUNCTION_CALL"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

    TEXT

    chunks = response.split("\n\n").map { |chunk| "#{chunk}\n\n" }

    with_scripted_responses([{ raw_stream: chunks }]) do
      output = []
      llm.generate("Hello", user: user) { |partial| output << partial }

      expect(output).to eq(
        [
          "Certainly",
          "! I'll create a simple \"Hello, World!\" page where each letter",
          " has a different color using inline styles for simplicity.  Each letter will be wrapped",
        ],
      )
    end
  end

  it "Can correctly handle streamed responses even if they are chunked badly" do
    data = +""
    data << "da|ta: |"
    data << gemini_chunk(parts: [{ text: "Hello" }]).to_json
    data << "\r\n\r\ndata: "
    data << gemini_chunk(parts: [{ text: " |World" }]).to_json
    data << "\r\n\r\ndata: "
    data << gemini_chunk(parts: [{ text: " Sam" }], finish_reason: "STOP").to_json
    data << "\r\n\r\n"

    chunks = data.split("|")

    with_scripted_responses([{ raw_stream: chunks }]) do
      output = []
      llm.generate("Hello", user: user) { |partial| output << partial }

      expect(output.join).to eq("Hello World Sam")
    end
  end

  it "can properly disable tool use with :none" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "Hello",
        tools: [echo_tool_definition],
        tool_choice: :none,
      )

    with_scripted_responses(["I won't use any tools"]) do |scripted_http|
      expect(llm.generate(prompt, user: user)).to eq("I won't use any tools")

      expect(scripted_http.last_request["tool_config"]).to eq(
        "function_calling_config" => {
          "mode" => "NONE",
        },
      )
    end
  end

  it "can properly force specific tool use" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "Hello",
        tools: [echo_tool_definition],
        tool_choice: "echo",
      )

    with_scripted_responses(["World"]) do |scripted_http|
      expect(llm.generate(prompt, user: user)).to eq("World")

      expect(scripted_http.last_request["tool_config"]).to eq(
        { "function_calling_config" => { "mode" => "ANY", "allowed_function_names" => ["echo"] } },
      )
    end
  end

  describe "structured output via JSON Schema" do
    it "forces the response to be a JSON" do
      schema = {
        type: "json_schema",
        json_schema: {
          name: "reply",
          schema: {
            type: "object",
            properties: {
              key: {
                type: "string",
              },
              num: {
                type: "integer",
              },
            },
            required: ["key"],
            additionalProperties: false,
          },
          strict: true,
        },
      }

      response = <<~TEXT.strip
        data: {"candidates": [{"content": {"parts": [{"text": "{\\""}],"role": "model"}}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "key"}],"role": "model"},"safetyRatings": [{"category": "HARM_CATEGORY_HATE_SPEECH","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HARASSMENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT","probability": "NEGLIGIBLE"}]}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "\\":\\""}],"role": "model"},"safetyRatings": [{"category": "HARM_CATEGORY_HATE_SPEECH","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HARASSMENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT","probability": "NEGLIGIBLE"}]}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "Hello!"}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "\\n "}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "there"}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "\\","}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "\\""}],"role": "model"}}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "num"}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "\\":"}],"role": "model"},"safetyRatings": [{"category": "HARM_CATEGORY_HATE_SPEECH","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HARASSMENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT","probability": "NEGLIGIBLE"}]}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "42"}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"content": {"parts": [{"text": "}"}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

        data: {"candidates": [{"finishReason": "MALFORMED_FUNCTION_CALL"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}
      TEXT

      chunks = response.split("\n\n").map { |chunk| "#{chunk}\n\n" }

      with_scripted_responses(
        [{ raw_stream: chunks.dup }, { raw_stream: chunks.dup }],
      ) do |scripted_http|
        structured_response = nil

        llm.generate("Hello", response_format: schema, user: user) do |partial|
          structured_response = partial if partial.respond_to?(:read_buffered_property)
        end

        expect(structured_response.read_buffered_property(:key)).to eq("Hello!\n there")
        expect(structured_response.read_buffered_property(:num)).to eq(42)

        first_request = scripted_http.last_request
        expect(first_request.dig("generationConfig", "responseSchema").deep_symbolize_keys).to eq(
          schema.dig(:json_schema, :schema).except(:additionalProperties),
        )
        expect(first_request.dig("generationConfig", "responseMimeType")).to eq("application/json")

        structured_response = nil

        llm.generate("Hello", response_format: schema.as_json, user: user) do |partial|
          structured_response = partial if partial.respond_to?(:read_buffered_property)
        end

        expect(structured_response.read_buffered_property(:key)).to eq("Hello!\n there")
        expect(structured_response.read_buffered_property(:num)).to eq(42)

        second_request = scripted_http.last_request
        expect(second_request.dig("generationConfig", "responseSchema").deep_symbolize_keys).to eq(
          schema.dig(:json_schema, :schema).except(:additionalProperties),
        )
        expect(second_request.dig("generationConfig", "responseMimeType")).to eq("application/json")
      end
    end
  end

  it "includes model params in the request" do
    with_scripted_responses(["Hello! This is a simple response"]) do |scripted_http|
      output = +""
      llm.generate("Hello", user: user, temperature: 0.2) { |partial| output << partial }

      expect(output).to eq("Hello! This is a simple response")
      expect(scripted_http.last_request.dig("generationConfig", "temperature")).to eq(0.2)
    end
  end

  it "handles inlineData in non-streaming response" do
    base64_data =
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="

    response = {
      candidates: [
        {
          content: {
            parts: [{ inlineData: { mimeType: "image/png", data: base64_data } }],
            role: "model",
          },
          finishReason: "STOP",
          index: 0,
        },
      ],
    }.to_json

    with_scripted_responses([{ raw_stream: [response] }]) do
      result = llm.generate("Show image", user: user)
      expect(result).to include("![image](")
    end
  end

  it "handles inlineData in streaming response" do
    base64_data =
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="

    response_chunks =
      sse_chunks(
        [
          gemini_chunk(parts: [{ inlineData: { mimeType: "image/png", data: base64_data } }]),
          gemini_chunk(parts: [{ text: "" }], finish_reason: "STOP"),
        ],
      )

    with_scripted_responses([{ raw_stream: response_chunks }]) do
      output = []
      llm.generate("Show image", user: user) { |partial| output << partial }

      expect(output.length).to eq(1)
      expect(output.first).to include("![image](")
    end
  end
end
