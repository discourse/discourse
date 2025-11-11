# frozen_string_literal: true

require_relative "endpoint_compliance"

class GeminiMock < EndpointMock
  def response(content, tool_call: false)
    {
      candidates: [
        {
          content: {
            parts: [(tool_call ? content : { text: content })],
            role: "model",
          },
          finishReason: "STOP",
          index: 0,
          safetyRatings: [
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_HARASSMENT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", probability: "NEGLIGIBLE" },
          ],
        },
      ],
      promptFeedback: {
        safetyRatings: [
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", probability: "NEGLIGIBLE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", probability: "NEGLIGIBLE" },
          { category: "HARM_CATEGORY_HARASSMENT", probability: "NEGLIGIBLE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", probability: "NEGLIGIBLE" },
        ],
      },
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=#{SiteSetting.ai_gemini_api_key}",
      )
      .with(body: request_body(prompt, tool_call))
      .to_return(status: 200, body: JSON.dump(response(response_text, tool_call: tool_call)))
  end

  def stream_line(delta, finish_reason: nil, tool_call: false)
    {
      candidates: [
        {
          content: {
            parts: [(tool_call ? delta : { text: delta })],
            role: "model",
          },
          finishReason: finish_reason,
          index: 0,
          safetyRatings: [
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_HARASSMENT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", probability: "NEGLIGIBLE" },
          ],
        },
      ],
    }.to_json
  end

  def stub_streamed_response(prompt, deltas, tool_call: false)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "STOP", tool_call: tool_call)
        else
          stream_line(deltas[index], tool_call: tool_call)
        end
      end

    chunks = chunks.join("\n,\n").prepend("[\n").concat("\n]").split("")

    WebMock
      .stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent?key=#{SiteSetting.ai_gemini_api_key}",
      )
      .with(body: request_body(prompt, tool_call))
      .to_return(status: 200, body: chunks)
  end

  def tool_payload
    {
      name: "get_weather",
      description: "Get the weather in a city",
      parameters: {
        type: "object",
        required: %w[location unit],
        properties: {
          "location" => {
            type: "string",
            description: "the city name",
          },
          "unit" => {
            type: "string",
            description: "the unit of measurement celcius c or fahrenheit f",
            enum: %w[c f],
          },
        },
      },
    }
  end

  def request_body(prompt, tool_call)
    model
      .default_options
      .merge(contents: prompt)
      .tap { |b| b[:tools] = [{ function_declarations: [tool_payload] }] if tool_call }
      .to_json
  end

  def tool_deltas
    [
      { "functionCall" => { name: "get_weather", args: {} } },
      { "functionCall" => { name: "get_weather", args: { location: "" } } },
      { "functionCall" => { name: "get_weather", args: { location: "Sydney", unit: "c" } } },
    ]
  end

  def tool_response
    { "functionCall" => { name: "get_weather", args: { location: "Sydney", unit: "c" } } }
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::Gemini do
  subject(:endpoint) { described_class.new(model) }

  fab!(:model) { Fabricate(:gemini_model, vision_enabled: true) }

  fab!(:user)

  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:upload100x100) do
    UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
  end

  let(:gemini_mock) { GeminiMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Gemini, user)
  end

  let(:echo_tool) do
    {
      name: "echo",
      description: "echo something",
      parameters: [{ name: "text", type: "string", description: "text to echo", required: true }],
    }
  end

  before { enable_current_plugin }

  it "correctly configures thinking when enabled" do
    model.update!(provider_params: { enable_thinking: "true", thinking_tokens: "10000" })

    response = gemini_mock.response("Using thinking mode").to_json

    req_body = nil

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).with(
      body:
        proc do |_req_body|
          req_body = _req_body
          true
        end,
    ).to_return(status: 200, body: response)

    response = llm.generate("Hello", user: user)

    parsed = JSON.parse(req_body, symbolize_names: true)

    # Verify thinking config is properly set with the token limit
    expect(parsed.dig(:generationConfig, :thinkingConfig)).to eq({ thinkingBudget: 10_000 })
  end

  it "correctly handles max output tokens" do
    model.update!(max_output_tokens: 1000)

    response = gemini_mock.response("some response mode").to_json

    req_body = nil

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).with(
      body:
        proc do |_req_body|
          req_body = _req_body
          true
        end,
    ).to_return(status: 200, body: response)

    response = llm.generate("Hello", user: user, max_tokens: 10_000)
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :maxOutputTokens)).to eq(1000)

    response = llm.generate("Hello", user: user, max_tokens: 50)
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :maxOutputTokens)).to eq(50)

    response = llm.generate("Hello", user: user)
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :maxOutputTokens)).to eq(1000)
  end

  it "clamps thinking tokens within allowed limits" do
    model.update!(provider_params: { enable_thinking: "true", thinking_tokens: "30000" })

    response = gemini_mock.response("Thinking tokens clamped").to_json

    req_body = nil

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).with(
      body:
        proc do |_req_body|
          req_body = _req_body
          true
        end,
    ).to_return(status: 200, body: response)

    response = llm.generate("Hello", user: user)

    parsed = JSON.parse(req_body, symbolize_names: true)

    # Verify thinking tokens are clamped to 24_576
    expect(parsed.dig(:generationConfig, :thinkingConfig)).to eq({ thinkingBudget: 24_576 })
  end

  it "does not add thinking config when disabled" do
    model.update!(provider_params: { enable_thinking: false, thinking_tokens: "10000" })

    response = gemini_mock.response("No thinking mode").to_json

    req_body = nil

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).with(
      body:
        proc do |_req_body|
          req_body = _req_body
          true
        end,
    ).to_return(status: 200, body: response)

    response = llm.generate("Hello", user: user)

    parsed = JSON.parse(req_body, symbolize_names: true)

    # Verify thinking config is not present
    expect(parsed.dig(:generationConfig, :thinkingConfig)).to be_nil
  end

  # by default gemini is meant to use AUTO mode, however new experimental models
  # appear to require this to be explicitly set
  it "Explicitly specifies tool config" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool])

    response = gemini_mock.response("World").to_json

    req_body = nil

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).with(
      body:
        proc do |_req_body|
          req_body = _req_body
          true
        end,
    ).to_return(status: 200, body: response)

    response = llm.generate(prompt, user: user)

    expect(response).to eq("World")

    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed[:tool_config]).to eq({ function_calling_config: { mode: "AUTO" } })
  end

  it "properly encodes tool calls" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool])

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    response_json = { "functionCall" => { name: "echo", args: { text: "<S>ydney" } } }
    response = gemini_mock.response(response_json, tool_call: true).to_json

    stub_request(:post, url).to_return(status: 200, body: response)

    response = llm.generate(prompt, user: user)

    tool =
      DiscourseAi::Completions::ToolCall.new(
        id: "tool_0",
        name: "echo",
        parameters: {
          text: "<S>ydney",
        },
      )

    expect(response).to eq(tool)
  end

  it "Supports Vision API" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are image bot",
        messages: [type: :user, id: "user1", content: ["hello", { upload_id: upload100x100.id }]],
      )

    encoded = prompt.encoded_uploads(prompt.messages.last)

    response = gemini_mock.response("World").to_json

    req_body = nil

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).with(
      body:
        proc do |_req_body|
          req_body = _req_body
          true
        end,
    ).to_return(status: 200, body: response)

    response = llm.generate(prompt, user: user)

    expect(response).to eq("World")

    expected_prompt = {
      "generationConfig" => {
      },
      "safetySettings" => [
        { "category" => "HARM_CATEGORY_HARASSMENT", "threshold" => "BLOCK_NONE" },
        { "category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold" => "BLOCK_NONE" },
        { "category" => "HARM_CATEGORY_HATE_SPEECH", "threshold" => "BLOCK_NONE" },
        { "category" => "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold" => "BLOCK_NONE" },
      ],
      "contents" => [
        {
          "role" => "user",
          "parts" => [
            { "text" => "user1: hello" },
            { "inlineData" => { "mimeType" => "image/jpeg", "data" => encoded[0][:base64] } },
          ],
        },
      ],
      "systemInstruction" => {
        "role" => "system",
        "parts" => [{ "text" => "You are image bot" }],
      },
    }

    expect(JSON.parse(req_body)).to eq(expected_prompt)
  end

  it "Can stream tool calls correctly" do
    rows = [
      {
        candidates: [
          {
            content: {
              parts: [{ functionCall: { name: "echo", args: { text: "sam<>wh!s" } } }],
              role: "model",
            },
            safetyRatings: [
              { category: "HARM_CATEGORY_HATE_SPEECH", probability: "NEGLIGIBLE" },
              { category: "HARM_CATEGORY_DANGEROUS_CONTENT", probability: "NEGLIGIBLE" },
              { category: "HARM_CATEGORY_HARASSMENT", probability: "NEGLIGIBLE" },
              { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", probability: "NEGLIGIBLE" },
            ],
          },
        ],
        usageMetadata: {
          promptTokenCount: 625,
          totalTokenCount: 625,
        },
        modelVersion: "gemini-1.5-pro-002",
      },
      {
        candidates: [{ content: { parts: [{ text: "" }], role: "model" }, finishReason: "STOP" }],
        usageMetadata: {
          promptTokenCount: 625,
          candidatesTokenCount: 4,
          totalTokenCount: 629,
        },
        modelVersion: "gemini-1.5-pro-002",
      },
    ]

    payload = rows.map { |r| "data: #{r.to_json}\n\n" }.join

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:streamGenerateContent?alt=sse&key=123"

    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool])

    output = []

    stub_request(:post, url).to_return(status: 200, body: payload)
    llm.generate(prompt, user: user) { |partial| output << partial }

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "tool_0",
        name: "echo",
        parameters: {
          text: "sam<>wh!s",
        },
      )

    expect(output).to eq([tool_call])

    log = AiApiAuditLog.order(:id).last
    expect(log.request_tokens).to eq(625)
    expect(log.response_tokens).to eq(4)
  end

  it "Can correctly handle malformed responses" do
    response = <<~TEXT
      data: {"candidates": [{"content": {"parts": [{"text": "Certainly"}],"role": "model"}}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

      data: {"candidates": [{"content": {"parts": [{"text": "! I'll create a simple \\"Hello, World!\\" page where each letter"}],"role": "model"},"safetyRatings": [{"category": "HARM_CATEGORY_HATE_SPEECH","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HARASSMENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT","probability": "NEGLIGIBLE"}]}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

      data: {"candidates": [{"content": {"parts": [{"text": " has a different color using inline styles for simplicity.  Each letter will be wrapped"}],"role": "model"},"safetyRatings": [{"category": "HARM_CATEGORY_HATE_SPEECH","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HARASSMENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT","probability": "NEGLIGIBLE"}]}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

      data: {"candidates": [{"content": {"parts": [{"text": ""}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

      data: {"candidates": [{"finishReason": "MALFORMED_FUNCTION_CALL"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

    TEXT

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:streamGenerateContent?alt=sse&key=123"

    output = []

    stub_request(:post, url).to_return(status: 200, body: response)
    llm.generate("Hello", user: user) { |partial| output << partial }

    expect(output).to eq(
      [
        "Certainly",
        "! I'll create a simple \"Hello, World!\" page where each letter",
        " has a different color using inline styles for simplicity.  Each letter will be wrapped",
      ],
    )
  end

  it "Can correctly handle streamed responses even if they are chunked badly" do
    data = +""
    data << "da|ta: |"
    data << gemini_mock.response("Hello").to_json
    data << "\r\n\r\ndata: "
    data << gemini_mock.response(" |World").to_json
    data << "\r\n\r\ndata: "
    data << gemini_mock.response(" Sam").to_json

    split = data.split("|")

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:streamGenerateContent?alt=sse&key=123"

    output = []
    gemini_mock.with_chunk_array_support do
      stub_request(:post, url).to_return(status: 200, body: split)
      llm.generate("Hello", user: user) { |partial| output << partial }
    end

    expect(output.join).to eq("Hello World Sam")
  end

  it "can properly disable tool use with :none" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool], tool_choice: :none)

    response = gemini_mock.response("I won't use any tools").to_json

    req_body = nil

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).with(
      body:
        proc do |_req_body|
          req_body = _req_body
          true
        end,
    ).to_return(status: 200, body: response)

    response = llm.generate(prompt, user: user)

    expect(response).to eq("I won't use any tools")

    parsed = JSON.parse(req_body, symbolize_names: true)

    # Verify that function_calling_config mode is set to "NONE"
    expect(parsed[:tool_config]).to eq({ function_calling_config: { mode: "NONE" } })
  end

  it "can properly force specific tool use" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool], tool_choice: "echo")

    response = gemini_mock.response("World").to_json

    req_body = nil

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).with(
      body:
        proc do |_req_body|
          req_body = _req_body
          _req_body
        end,
    ).to_return(status: 200, body: response)

    response = llm.generate(prompt, user: user)

    parsed = JSON.parse(req_body, symbolize_names: true)

    # Verify that function_calling_config is correctly set to ANY mode with the specified tool
    expect(parsed[:tool_config]).to eq(
      { function_calling_config: { mode: "ANY", allowed_function_names: ["echo"] } },
    )
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

      req_body = nil

      llm = DiscourseAi::Completions::Llm.proxy(model)
      url = "#{model.url}:streamGenerateContent?alt=sse&key=123"

      stub_request(:post, url).with(
        body:
          proc do |_req_body|
            req_body = _req_body
            true
          end,
      ).to_return(status: 200, body: response)

      structured_response = nil

      llm.generate("Hello", response_format: schema, user: user) do |partial|
        structured_response = partial
      end

      expect(structured_response.read_buffered_property(:key)).to eq("Hello!\n there")
      expect(structured_response.read_buffered_property(:num)).to eq(42)

      parsed = JSON.parse(req_body, symbolize_names: true)

      # Verify that schema is passed following Gemini API specs.
      expect(parsed.dig(:generationConfig, :responseSchema)).to eq(
        schema.dig(:json_schema, :schema).except(:additionalProperties),
      )
      expect(parsed.dig(:generationConfig, :responseMimeType)).to eq("application/json")

      structured_response = nil
      # once more but this time lets have the schema as string keys
      llm.generate("Hello", response_format: schema.as_json, user: user) do |partial|
        structured_response = partial
      end

      expect(structured_response.read_buffered_property(:key)).to eq("Hello!\n there")
      expect(structured_response.read_buffered_property(:num)).to eq(42)

      parsed = JSON.parse(req_body, symbolize_names: true)

      # Verify that schema is passed following Gemini API specs.
      expect(parsed.dig(:generationConfig, :responseSchema)).to eq(
        schema.dig(:json_schema, :schema).except(:additionalProperties),
      )
      expect(parsed.dig(:generationConfig, :responseMimeType)).to eq("application/json")
    end
  end

  it "includes model params in the request" do
    response = <<~TEXT
    data: {"candidates": [{"content": {"parts": [{"text": "Hello"}],"role": "model"}}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

    data: {"candidates": [{"content": {"parts": [{"text": "! This is a simple response"}],"role": "model"},"safetyRatings": [{"category": "HARM_CATEGORY_HATE_SPEECH","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_HARASSMENT","probability": "NEGLIGIBLE"},{"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT","probability": "NEGLIGIBLE"}]}],"usageMetadata": {"promptTokenCount": 399,"totalTokenCount": 399},"modelVersion": "gemini-1.5-pro-002"}

    data: {"candidates": [{"content": {"parts": [{"text": ""}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 399,"candidatesTokenCount": 191,"totalTokenCount": 590},"modelVersion": "gemini-1.5-pro-002"}

  TEXT

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:streamGenerateContent?alt=sse&key=123"

    output = []

    stub_request(:post, url).with(
      body: hash_including(generationConfig: { temperature: 0.2 }),
    ).to_return(status: 200, body: response)

    llm.generate("Hello", user: user, temperature: 0.2) { |partial| output << partial }

    expect(output).to eq(["Hello", "! This is a simple response"])
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
          safetyRatings: [
            { category: "HARM_CATEGORY_HATE_SPEECH", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_HARASSMENT", probability: "NEGLIGIBLE" },
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", probability: "NEGLIGIBLE" },
          ],
        },
      ],
    }.to_json

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).to_return(status: 200, body: response)

    result = llm.generate("Show image", user: user)
    expect(result).to include("![image](")
  end

  it "handles inlineData in streaming response" do
    base64_data =
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
    rows = [
      {
        candidates: [
          {
            content: {
              parts: [{ inlineData: { mimeType: "image/png", data: base64_data } }],
              role: "model",
            },
            safetyRatings: [
              { category: "HARM_CATEGORY_HATE_SPEECH", probability: "NEGLIGIBLE" },
              { category: "HARM_CATEGORY_DANGEROUS_CONTENT", probability: "NEGLIGIBLE" },
              { category: "HARM_CATEGORY_HARASSMENT", probability: "NEGLIGIBLE" },
              { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", probability: "NEGLIGIBLE" },
            ],
          },
        ],
      },
      { candidates: [{ content: { parts: [{ text: "" }], role: "model" }, finishReason: "STOP" }] },
    ]

    payload = rows.map { |r| "data: #{r.to_json}\n\n" }.join

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:streamGenerateContent?alt=sse&key=123"

    output = []

    stub_request(:post, url).to_return(status: 200, body: payload)

    llm.generate("Show image", user: user) { |partial| output << partial }

    expect(output.length).to eq(1)
    expect(output.first).to include("![image](")
  end
end
