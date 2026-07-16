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

  def minimal_pdf_content
    <<~PDF
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
  end

  def build_pdf_upload
    SiteSetting.authorized_extensions = "*"
    file = Tempfile.new(%w[test-pdf .pdf])
    file.binmode
    file.write(minimal_pdf_content)
    file.rewind
    UploadCreator.new(file, "document.pdf").create_for(Discourse.system_user.id)
  ensure
    file.close! if file
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

  def gemini_rate_limit_body(retry_delay: "45s")
    {
      error: {
        code: 429,
        message: "quota exceeded",
        status: "RESOURCE_EXHAUSTED",
        details: [{ "@type": "type.googleapis.com/google.rpc.RetryInfo", retryDelay: retry_delay }],
      },
    }.to_json
  end

  before { enable_current_plugin }

  it "uses Gemini RetryInfo retryDelay from rate limit response bodies" do
    DiscourseAi::Completions::Endpoints::Gemini.any_instance.stubs(:retry_jitter).returns(0)
    DiscourseAi::Completions::Endpoints::Gemini
      .any_instance
      .expects(:sleep_before_retry)
      .with(45, nil)
      .once

    url = "#{model.url}:generateContent?key=123"
    request =
      stub_request(:post, url).to_return(
        { status: 429, body: gemini_rate_limit_body(retry_delay: "45s") },
        { status: 200, body: gemini_mock.response("ok").to_json },
      )

    llm = DiscourseAi::Completions::Llm.proxy(model)

    expect(llm.generate("Hello", user: user)).to eq("ok")
    expect(request).to have_been_requested.times(2)
    expect(AiApiAuditLog.last.request_attempts).to eq(
      [{ "status" => 429, "delay_ms" => 0 }, { "status" => 200, "delay_ms" => 45_000 }],
    )
  end

  it "caps Gemini RetryInfo retryDelay from rate limit response bodies" do
    DiscourseAi::Completions::Endpoints::Gemini.any_instance.stubs(:retry_jitter).returns(0)
    DiscourseAi::Completions::Endpoints::Gemini
      .any_instance
      .expects(:sleep_before_retry)
      .with(60, nil)
      .once

    url = "#{model.url}:generateContent?key=123"
    stub_request(:post, url).to_return(
      { status: 429, body: gemini_rate_limit_body(retry_delay: "120s") },
      { status: 200, body: gemini_mock.response("ok").to_json },
    )

    llm = DiscourseAi::Completions::Llm.proxy(model)

    expect(llm.generate("Hello", user: user)).to eq("ok")
  end

  it "ignores oversized Gemini rate limit response bodies when extracting retry delays" do
    DiscourseAi::Completions::Endpoints::Gemini.any_instance.stubs(:retry_jitter).returns(0)
    DiscourseAi::Completions::Endpoints::Gemini
      .any_instance
      .expects(:sleep_before_retry)
      .with(2, nil)
      .once

    url = "#{model.url}:generateContent?key=123"
    stub_request(:post, url).to_return(
      { status: 429, body: gemini_rate_limit_body(retry_delay: "45s") + (" " * 10_000) },
      { status: 200, body: gemini_mock.response("ok").to_json },
    )

    llm = DiscourseAi::Completions::Llm.proxy(model)

    expect(llm.generate("Hello", user: user)).to eq("ok")
  end

  it "uses the larger retry delay from Gemini RetryInfo and Retry-After" do
    DiscourseAi::Completions::Endpoints::Gemini.any_instance.stubs(:retry_jitter).returns(0)
    DiscourseAi::Completions::Endpoints::Gemini
      .any_instance
      .expects(:sleep_before_retry)
      .with(10, nil)
      .once

    url = "#{model.url}:generateContent?key=123"
    stub_request(:post, url).to_return(
      {
        status: 429,
        body: gemini_rate_limit_body(retry_delay: "10s"),
        headers: {
          "Retry-After" => "5",
        },
      },
      { status: 200, body: gemini_mock.response("ok").to_json },
    )

    llm = DiscourseAi::Completions::Llm.proxy(model)

    expect(llm.generate("Hello", user: user)).to eq("ok")
  end

  it "uses Gemini RetryInfo retryDelay for transient errors" do
    DiscourseAi::Completions::Endpoints::Gemini.any_instance.stubs(:retry_jitter).returns(0)
    DiscourseAi::Completions::Endpoints::Gemini
      .any_instance
      .expects(:sleep_before_retry)
      .with(12, nil)
      .once

    url = "#{model.url}:generateContent?key=123"
    stub_request(:post, url).to_return(
      { status: 503, body: gemini_rate_limit_body(retry_delay: "12s") },
      { status: 200, body: gemini_mock.response("ok").to_json },
    )

    llm = DiscourseAi::Completions::Llm.proxy(model)

    expect(llm.generate("Hello", user: user)).to eq("ok")
  end

  it "supports fractional Gemini RetryInfo retryDelay values" do
    DiscourseAi::Completions::Endpoints::Gemini.any_instance.stubs(:retry_jitter).returns(0)
    DiscourseAi::Completions::Endpoints::Gemini
      .any_instance
      .expects(:sleep_before_retry)
      .with(2.5, nil)
      .once

    url = "#{model.url}:generateContent?key=123"
    stub_request(:post, url).to_return(
      { status: 429, body: gemini_rate_limit_body(retry_delay: "2.5s") },
      { status: 200, body: gemini_mock.response("ok").to_json },
    )

    llm = DiscourseAi::Completions::Llm.proxy(model)

    expect(llm.generate("Hello", user: user)).to eq("ok")
  end

  it "ignores non-positive Gemini RetryInfo retryDelay values" do
    DiscourseAi::Completions::Endpoints::Gemini.any_instance.stubs(:retry_jitter).returns(0)
    DiscourseAi::Completions::Endpoints::Gemini
      .any_instance
      .expects(:sleep_before_retry)
      .with(2, nil)
      .once

    url = "#{model.url}:generateContent?key=123"
    stub_request(:post, url).to_return(
      { status: 429, body: gemini_rate_limit_body(retry_delay: "0s") },
      { status: 200, body: gemini_mock.response("ok").to_json },
    )

    llm = DiscourseAi::Completions::Llm.proxy(model)

    expect(llm.generate("Hello", user: user)).to eq("ok")
  end

  it "finds Gemini RetryInfo among other error details" do
    DiscourseAi::Completions::Endpoints::Gemini.any_instance.stubs(:retry_jitter).returns(0)
    DiscourseAi::Completions::Endpoints::Gemini
      .any_instance
      .expects(:sleep_before_retry)
      .with(7, nil)
      .once

    url = "#{model.url}:generateContent?key=123"
    body = {
      error: {
        code: 429,
        details: [
          { "@type": "type.googleapis.com/google.rpc.Help" },
          { "@type": "type.googleapis.com/google.rpc.RetryInfo", retryDelay: "7s" },
        ],
      },
    }.to_json
    stub_request(:post, url).to_return(
      { status: 429, body: body },
      { status: 200, body: gemini_mock.response("ok").to_json },
    )

    llm = DiscourseAi::Completions::Llm.proxy(model)

    expect(llm.generate("Hello", user: user)).to eq("ok")
  end

  it "ignores invalid Gemini rate limit response bodies when extracting retry delays" do
    DiscourseAi::Completions::Endpoints::Gemini.any_instance.stubs(:retry_jitter).returns(0)
    DiscourseAi::Completions::Endpoints::Gemini
      .any_instance
      .expects(:sleep_before_retry)
      .with(2, nil)
      .once

    url = "#{model.url}:generateContent?key=123"
    stub_request(:post, url).to_return(
      { status: 429, body: "{" },
      { status: 200, body: gemini_mock.response("ok").to_json },
    )

    llm = DiscourseAi::Completions::Llm.proxy(model)

    expect(llm.generate("Hello", user: user)).to eq("ok")
  end

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

  it "correctly configures thinking level when set" do
    model.update!(
      name: "gemini-3-flash",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview",
      provider_params: {
        enable_thinking: true,
        thinking_level: "high",
      },
    )

    response = gemini_mock.response("Using thinking level").to_json
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

    expect(parsed.dig(:generationConfig, :thinkingConfig)).to eq({ thinkingLevel: "high" })
  end

  it "requests Gemini thought summaries when enabled" do
    model.update!(
      name: "gemini-3-flash",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview",
      provider_params: {
        enable_thinking: true,
        thinking_level: "medium",
      },
    )

    response = gemini_mock.response("Using thought summaries").to_json
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

    llm.generate(
      "Hello",
      user: user,
      output_thinking: true,
      extra_model_params: {
        include_thought_summaries: true,
      },
    )

    parsed = JSON.parse(req_body, symbolize_names: true)
    expect(parsed.dig(:generationConfig, :thinkingConfig)).to eq(
      { thinkingLevel: "medium", includeThoughts: true },
    )
  end

  it "decodes non-streamed thought summaries as thinking" do
    response = {
      candidates: [
        {
          content: {
            parts: [
              { text: "I should inspect the provided URL.", thought: true },
              { text: "The URL contains latest topic data." },
            ],
            role: "model",
          },
        },
      ],
    }.to_json

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).to_return(status: 200, body: response)

    result = llm.generate("Hello", user: user, output_thinking: true)

    expect(result.first).to be_a(DiscourseAi::Completions::Thinking)
    expect(result.first.message).to eq("I should inspect the provided URL.")
    expect(result.last).to eq("The URL contains latest topic data.")
  end

  it "streams thought summaries separately from answer text" do
    payload =
      [
        {
          candidates: [
            { content: { parts: [{ text: "I should ", thought: true }], role: "model" } },
          ],
        },
        {
          candidates: [
            { content: { parts: [{ text: "inspect the URL.", thought: true }], role: "model" } },
          ],
        },
        { candidates: [{ content: { parts: [{ text: "Answer text" }], role: "model" } }] },
      ].map { |row| "data: #{row.to_json}\n\n" }.join

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:streamGenerateContent?alt=sse&key=123"
    output = []

    stub_request(:post, url).to_return(status: 200, body: payload)

    result =
      llm.generate("Hello", user: user, output_thinking: true) { |partial| output << partial }

    expect(
      output.map do |partial|
        partial.is_a?(String) ? partial : [partial.message, partial.partial?]
      end,
    ).to eq(
      [
        ["I should ", true],
        ["inspect the URL.", true],
        ["I should inspect the URL.", false],
        "Answer text",
      ],
    )
    expect(result).to eq("Answer text")
  end

  it "thinking_level takes priority over enable_thinking" do
    model.update!(
      name: "gemini-3-flash",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview",
      provider_params: {
        enable_thinking: true,
        thinking_level: "medium",
        thinking_tokens: "10000",
      },
    )

    response = gemini_mock.response("Thinking level priority").to_json
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

    expect(parsed.dig(:generationConfig, :thinkingConfig)).to eq({ thinkingLevel: "medium" })
  end

  it "does not add thinking config when thinking_level is default" do
    model.update!(provider_params: { thinking_level: "default" })

    response = gemini_mock.response("No thinking config").to_json
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

    expect(parsed.dig(:generationConfig, :thinkingConfig)).to be_nil
  end

  it "maps thinking_effort to Gemini 3 thinking levels" do
    model.update!(
      name: "gemini-3-flash",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview",
    )

    response = gemini_mock.response("Using thinking effort").to_json
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

    llm.generate("Hello", user: user, thinking_effort: "xhigh", temperature: 0.5)
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :thinkingConfig)).to eq({ thinkingLevel: "high" })
    expect(parsed.dig(:generationConfig, :temperature)).to be_nil
  end

  it "maps minimal thinking_effort to low for Gemini 3.1 Pro" do
    model.update!(
      name: "gemini-3.1-pro",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro-preview",
    )

    response = gemini_mock.response("Using minimal effort").to_json
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

    llm.generate("Hello", user: user, thinking_effort: "minimal")
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :thinkingConfig)).to eq({ thinkingLevel: "low" })
  end

  it "maps unsupported Gemini 3 Pro thinking levels to supported levels" do
    model.update!(
      name: "gemini-3-pro",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-preview",
    )

    response = gemini_mock.response("Using medium effort").to_json
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

    llm.generate("Hello", user: user, thinking_effort: "medium")
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :thinkingConfig)).to eq({ thinkingLevel: "high" })
  end

  it "uses thinkingBudget 0 for explicit none thinking_effort" do
    response = gemini_mock.response("No thinking").to_json
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

    llm.generate(
      "Hello",
      user: user,
      thinking_effort: "none",
      output_thinking: true,
      extra_model_params: {
        include_thought_summaries: true,
      },
    )
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :thinkingConfig)).to eq({ thinkingBudget: 0 })
  end

  it "omits thinkingConfig entirely for none on Gemini 3 Pro-tier models that can't disable thinking" do
    model.update!(
      name: "gemini-3.1-pro",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro-preview",
    )
    response = gemini_mock.response("Still thinking").to_json
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

    llm.generate("Hello", user: user, thinking_effort: "none")
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :thinkingConfig)).to be_nil
  end

  it "does not send thinking levels to pre-Gemini 3 generateContent models" do
    response = gemini_mock.response("Unsupported thinking level").to_json
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

    llm.generate("Hello", user: user, thinking_effort: "high")
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :thinkingConfig)).to be_nil
  end

  it "adds configured service tier using the Gemini API field name" do
    response = gemini_mock.response("Configured service tier").to_json
    url = "#{model.url}:generateContent?key=123"

    captured_bodies = []
    stub_request(:post, url).with(
      body:
        proc do |req_body|
          captured_bodies << JSON.parse(req_body, symbolize_names: true)
          true
        end,
    ).to_return(status: 200, body: response)

    {
      "default" => nil,
      "standard" => "standard",
      "flex" => "flex",
      "priority" => "priority",
    }.each do |configured_tier, expected_tier|
      model.update!(provider_params: { service_tier: configured_tier })

      DiscourseAi::Completions::Llm.proxy(model).generate("Hello", user: user)

      payload = captured_bodies.last
      if expected_tier
        expect(payload[:serviceTier]).to eq(expected_tier)
      else
        expect(payload).not_to have_key(:serviceTier)
      end
      expect(payload).not_to have_key(:service_tier)
    end
  end

  it "omits service tier when it is not configured" do
    response = gemini_mock.response("No service tier").to_json
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

    llm.generate("Hello", user: user)

    expect(JSON.parse(req_body, symbolize_names: true)).not_to have_key(:serviceTier)
  end

  it "omits service tier when it is invalid" do
    model.update!(provider_params: { service_tier: "invalid" })

    response = gemini_mock.response("Invalid service tier").to_json
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

    llm.generate("Hello", user: user)

    expect(JSON.parse(req_body, symbolize_names: true)).not_to have_key(:serviceTier)
  end

  it "strips temperature when thinking_level is set" do
    model.update!(
      name: "gemini-3-flash",
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview",
      provider_params: {
        enable_thinking: true,
        thinking_level: "high",
      },
    )

    response = gemini_mock.response("Stripped temp").to_json
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

    response = llm.generate("Hello", user: user, temperature: 0.5)
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :temperature)).to be_nil
  end

  it "strips temperature when enable_thinking is set" do
    model.update!(provider_params: { enable_thinking: "true", thinking_tokens: "10000" })

    response = gemini_mock.response("Stripped temp").to_json
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

    response = llm.generate("Hello", user: user, temperature: 0.5)
    parsed = JSON.parse(req_body, symbolize_names: true)

    expect(parsed.dig(:generationConfig, :temperature)).to be_nil
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

  it "sends google_search grounding without a function_calling_config when only native tools are present" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello")
    prompt.native_tools = ["web_search"]

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

    # Gemini rejects function_calling_config when there are no function_declarations
    expect(parsed[:tools]).to eq([{ google_search: {} }])
    expect(parsed).not_to have_key(:tool_config)
  end

  it "emits native web search thinking from grounding metadata" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello")
    prompt.native_tools = ["web_search"]

    grounding_metadata = {
      webSearchQueries: ["OpenAI news"],
      searchEntryPoint: {
        renderedContent: "<div>Search suggestions</div>",
      },
      groundingChunks: [{ web: { uri: "https://openai.com/news", title: "OpenAI" } }],
      groundingSupports: [
        {
          segment: {
            startIndex: 0,
            endIndex: 15,
            text: "Grounded answer",
          },
          groundingChunkIndices: [0],
        },
      ],
    }
    response = {
      candidates: [
        {
          content: {
            parts: [{ text: "Grounded answer" }],
            role: "model",
          },
          groundingMetadata: grounding_metadata,
        },
      ],
    }.to_json

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).to_return(status: 200, body: response)

    result = llm.generate(prompt, user: user, output_thinking: true)

    expect(result.first).to eq("Grounded answer")
    expect(result.last).to be_a(DiscourseAi::Completions::Thinking)
    expect(result.last.message).to eq("Web search: OpenAI news")
    expect(result.last.provider_info.dig(:gemini, :grounding_metadata)).to eq(
      grounding_metadata.except(:searchEntryPoint),
    )
  end

  it "streams native web search thinking from grounding metadata" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello")
    prompt.native_tools = ["web_search"]

    rows = [
      { candidates: [{ content: { parts: [{ text: "Grounded " }], role: "model" } }] },
      { candidates: [{ content: { parts: [{ text: "answer" }], role: "model" } }] },
      {
        candidates: [
          {
            content: {
              parts: [{ text: "", thoughtSignature: "sig-123" }],
              role: "model",
            },
            finishReason: "STOP",
            groundingMetadata: {
              webSearchQueries: ["OpenAI news", "Anthropic news"],
              groundingChunks: [{ web: { uri: "https://openai.com/news", title: "OpenAI" } }],
            },
          },
        ],
      },
    ]
    payload = rows.map { |row| "data: #{row.to_json}\n\n" }.join

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:streamGenerateContent?alt=sse&key=123"
    output = []

    stub_request(:post, url).to_return(status: 200, body: payload)

    result = llm.generate(prompt, user: user, output_thinking: true) { |partial| output << partial }
    thinking = output.find { |partial| partial.is_a?(DiscourseAi::Completions::Thinking) }

    expect(output.map { |partial| partial.is_a?(String) ? partial : partial.message }).to eq(
      ["Grounded ", "answer", "Web search: OpenAI news, Anthropic news"],
    )
    expect(thinking.provider_info.dig(:gemini, :grounding_metadata, :webSearchQueries)).to eq(
      ["OpenAI news", "Anthropic news"],
    )
    expect(thinking.provider_info.dig(:gemini, :thought_signature_parts)).to eq(
      [{ text: "", thoughtSignature: "sig-123" }],
    )
    expect(Array(result).join).to eq("Grounded answer")
  end

  it "keeps grounding metadata hidden when Gemini does not include search queries" do
    payload =
      [
        { candidates: [{ content: { parts: [{ text: "Fetched answer" }], role: "model" } }] },
        {
          candidates: [
            {
              content: {
                parts: [{ text: "", thoughtSignature: "sig-789" }],
                role: "model",
              },
              finishReason: "STOP",
              groundingMetadata: {
                groundingChunks: [
                  { web: { uri: "https://meta.discourse.org/latest.json", title: "Meta" } },
                ],
                groundingSupports: [
                  {
                    segment: {
                      startIndex: 0,
                      endIndex: 14,
                      text: "Fetched answer",
                    },
                    groundingChunkIndices: [0],
                  },
                ],
              },
              urlContextMetadata: {
                urlMetadata: [
                  {
                    retrievedUrl: "https://meta.discourse.org/latest.json",
                    urlRetrievalStatus: "URL_RETRIEVAL_STATUS_SUCCESS",
                  },
                ],
              },
            },
          ],
        },
      ].map { |row| "data: #{row.to_json}\n\n" }.join

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:streamGenerateContent?alt=sse&key=123"
    output = []

    stub_request(:post, url).to_return(status: 200, body: payload)

    llm.generate("Hello", user: user, output_thinking: true) { |partial| output << partial }

    expect(output.map { |partial| partial.is_a?(String) ? partial : partial.message }).to eq(
      ["Fetched answer", nil, "Web fetch: https://meta.discourse.org/latest.json"],
    )
    expect(output.grep(DiscourseAi::Completions::Thinking).first.provider_info[:gemini]).to include(
      :grounding_metadata,
      :thought_signature_parts,
    )
  end

  it "emits hidden thinking for streamed text thought signatures" do
    payload =
      [
        { candidates: [{ content: { parts: [{ text: "Hello" }], role: "model" } }] },
        {
          candidates: [
            {
              content: {
                parts: [{ text: "", thoughtSignature: "sig-456" }],
                role: "model",
              },
              finishReason: "STOP",
            },
          ],
        },
      ].map { |row| "data: #{row.to_json}\n\n" }.join

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:streamGenerateContent?alt=sse&key=123"
    output = []

    stub_request(:post, url).to_return(status: 200, body: payload)

    result =
      llm.generate("Hello", user: user, output_thinking: true) { |partial| output << partial }
    thinking = output.find { |partial| partial.is_a?(DiscourseAi::Completions::Thinking) }

    expect(output.map { |partial| partial.is_a?(String) ? partial : partial.message }).to eq(
      ["Hello", nil],
    )
    expect(thinking.provider_info.dig(:gemini, :thought_signature_parts)).to eq(
      [{ text: "", thoughtSignature: "sig-456" }],
    )
    expect(Array(result).join).to eq("Hello")
  end

  it "emits native web fetch thinking from URL context metadata" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello")
    prompt.native_tools = ["web_fetch"]

    url_context_metadata = {
      urlMetadata: [
        {
          retrievedUrl: "https://example.com/report",
          urlRetrievalStatus: "URL_RETRIEVAL_STATUS_SUCCESS",
        },
      ],
    }
    response = {
      candidates: [
        {
          content: {
            parts: [{ text: "Fetched answer" }],
            role: "model",
          },
          urlContextMetadata: url_context_metadata,
        },
      ],
    }.to_json

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    stub_request(:post, url).to_return(status: 200, body: response)

    result = llm.generate(prompt, user: user, output_thinking: true)

    expect(result.first).to eq("Fetched answer")
    expect(result.last).to be_a(DiscourseAi::Completions::Thinking)
    expect(result.last.message).to eq("Web fetch: https://example.com/report")
    expect(result.last.provider_info.dig(:gemini, :url_context_metadata)).to eq(
      url_context_metadata,
    )
  end

  it "properly encodes tool calls" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool])

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    response_json = { "functionCall" => { name: "echo", args: { text: "<S>ydney" } } }
    response = gemini_mock.response(response_json, tool_call: true).to_json

    stub_request(:post, url).to_return(status: 200, body: response)

    response = llm.generate(prompt, user: user)

    expect(response).to be_a(DiscourseAi::Completions::ToolCall)
    expect(response.parameters[:text]).to eq("<S>ydney")
    expect(response.provider_data[:batch_id]).to match(/\A[0-9a-f]{16}\z/)
  end

  it "returns tool calls with thought signatures in provider data" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool])

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    response_json = {
      "functionCall" => {
        name: "echo",
        args: {
          text: "Sydney",
        },
      },
      "thoughtSignature" => "abc123",
    }
    response = gemini_mock.response(response_json, tool_call: true).to_json

    stub_request(:post, url).to_return(status: 200, body: response)

    result = llm.generate(prompt, user: user)

    expect(result).to be_a(DiscourseAi::Completions::ToolCall)
    expect(result.provider_data[:thought_signature]).to eq("abc123")
  end

  it "returns batch-aware tool calls when multiple are emitted in one message" do
    prompt = DiscourseAi::Completions::Prompt.new("Hello", tools: [echo_tool])

    llm = DiscourseAi::Completions::Llm.proxy(model)
    url = "#{model.url}:generateContent?key=123"

    batch_response = {
      candidates: [
        {
          content: {
            parts: [
              {
                functionCall: {
                  name: "get_weather",
                  args: {
                    city: "Paris",
                  },
                },
                thoughtSignature: "Signature_A",
              },
              { functionCall: { name: "get_weather", args: { city: "London" } } },
            ],
            role: "model",
          },
          finishReason: "STOP",
          index: 0,
        },
      ],
    }

    stub_request(:post, url).to_return(status: 200, body: batch_response.to_json)

    results = llm.generate(prompt, user: user)

    expect(results).to be_an(Array)
    expect(results.size).to eq(2)

    batch_ids = results.map { |r| r.provider_data[:batch_id] }.uniq
    expect(batch_ids.length).to eq(1)
    expect(batch_ids.first).to match(/\A[0-9a-f]{16}\z/)

    expect(results.first.provider_data[:thought_signature]).to eq("Signature_A")
    expect(results.second.provider_data[:thought_signature]).to be_nil
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

  it "passes pdf documents using inlineData" do
    model.update!(allowed_attachment_types: %w[pdf])
    pdf_upload = build_pdf_upload

    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are pdf bot",
        messages: [type: :user, id: "user1", content: ["hello", { upload_id: pdf_upload.id }]],
      )

    encoded = prompt.encoded_uploads(prompt.messages.last, allow_documents: true)

    response = gemini_mock.response("PDF processed").to_json

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

    expect(response).to eq("PDF processed")

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
            { "inlineData" => { "mimeType" => "application/pdf", "data" => encoded[0][:base64] } },
          ],
        },
      ],
      "systemInstruction" => {
        "role" => "system",
        "parts" => [{ "text" => "You are pdf bot" }],
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
        provider_data: {
          batch_id: output.first.provider_data[:batch_id],
        },
      )

    expect(output.first.provider_data[:batch_id]).to match(/\A[0-9a-f]{16}\z/)
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
    SiteSetting.ai_llm_temperature_top_p_enabled = true
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
