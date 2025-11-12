# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Scripted::HttpClient do
  fab!(:user)
  fab!(:open_ai_model, :llm_model)
  fab!(:gemini_model, :gemini_model)
  fab!(:anthropic_model, :anthropic_model)
  fab!(:bedrock_claude_model, :bedrock_model)
  fab!(:bedrock_nova_model, :nova_model)
  fab!(:hf_model)
  fab!(:vllm_model)

  before { enable_current_plugin }

  def build_request(uri, body)
    Net::HTTP::Post.new(uri).tap { |request| request.body = body }
  end

  def decode_event_stream_chunks(chunks)
    decoder = Aws::EventStream::Decoder.new
    payloads = []

    chunks.each do |chunk|
      message, _done = decoder.decode_chunk(chunk)
      while message
        parsed = JSON.parse(message.payload.string)
        bytes = parsed["bytes"] ? Base64.decode64(parsed["bytes"]) : ""
        payloads << JSON.parse(bytes) if bytes.present?
        message, _done = decoder.decode_chunk
      end
    end

    payloads
  end

  describe ".for" do
    it "selects the OpenAI style for OpenAI-compatible providers" do
      client = described_class.for(llm_model: open_ai_model, responses: ["hi"])
      expect(client.strategy).to be_a(DiscourseAi::Completions::Scripted::OpenAiApiStyle)
    end

    it "selects the Gemini style for Google providers" do
      client = described_class.for(llm_model: gemini_model, responses: ["hi"])
      expect(client.strategy).to be_a(DiscourseAi::Completions::Scripted::GeminiApiStyle)
    end

    it "selects the Anthropic style for Anthropic providers" do
      client = described_class.for(llm_model: anthropic_model, responses: ["hi"])
      expect(client.strategy).to be_a(DiscourseAi::Completions::Scripted::AnthropicApiStyle)
    end

    it "selects the Bedrock Anthropic style for Bedrock Claude providers" do
      client = described_class.for(llm_model: bedrock_claude_model, responses: ["hi"])
      expect(client.strategy).to be_a(DiscourseAi::Completions::Scripted::BedrockAnthropicApiStyle)
    end

    it "selects the Bedrock Nova style for Nova providers" do
      client = described_class.for(llm_model: bedrock_nova_model, responses: ["hi"])
      expect(client.strategy).to be_a(DiscourseAi::Completions::Scripted::BedrockNovaApiStyle)
    end

    it "selects the OpenAI style for Hugging Face providers" do
      client = described_class.for(llm_model: hf_model, responses: ["hi"])
      expect(client.strategy).to be_a(DiscourseAi::Completions::Scripted::OpenAiApiStyle)
    end

    it "selects the vLLM style for vLLM providers" do
      client = described_class.for(llm_model: vllm_model, responses: ["hi"])
      expect(client.strategy).to be_a(DiscourseAi::Completions::Scripted::VllmApiStyle)
    end
  end

  describe DiscourseAi::Completions::Scripted::OpenAiApiStyle do
    let(:uri) { URI(open_ai_model.url) }
    let(:payload) { { model: open_ai_model.name, messages: [{ role: "user", content: "Hello?" }] } }

    def style_for(responses)
      DiscourseAi::Completions::Scripted::OpenAiApiStyle.new(Array.wrap(responses), open_ai_model)
    end

    it "produces a chat completion payload for message responses" do
      response = style_for(["scripted message"]).request(build_request(uri, payload.to_json))

      body = JSON.parse(response.body)
      expect(body.dig("choices", 0, "message", "content")).to eq("scripted message")
      expect(body.dig("choices", 0, "finish_reason")).to eq("stop")
    end

    it "streams message responses as SSE chunks" do
      streaming_payload = payload.merge(stream: true)
      response = style_for(["Stream me"]).request(build_request(uri, streaming_payload.to_json))

      chunks = []
      response.read_body { |chunk| chunks << chunk }

      expect(chunks.length).to be > 1
      expect(chunks.first).to start_with("data: ")
      expect(chunks.last).to include("\"finish_reason\":\"stop\"")
    end

    it "returns tool call payloads" do
      tool_responses = [{ tool_calls: [{ name: "lookup_weather", arguments: { city: "Paris" } }] }]
      response = style_for(tool_responses).request(build_request(uri, payload.to_json))

      body = JSON.parse(response.body)
      tool_call = body.dig("choices", 0, "message", "tool_calls", 0)

      expect(tool_call.dig("function", "name")).to eq("lookup_weather")
      expect(JSON.parse(tool_call.dig("function", "arguments"))).to eq("city" => "Paris")
    end

    it "streams tool call payloads" do
      streaming_payload = payload.merge(stream: true)
      tool_response = [{ tool_calls: [{ name: "lookup_weather", arguments: { city: "Paris" } }] }]
      response = style_for(tool_response).request(build_request(uri, streaming_payload.to_json))

      chunks = []
      response.read_body { |chunk| chunks << chunk }

      expect(chunks.first).to include("\"name\":\"lookup_weather\"")
      expect(chunks.last).to include("\"finish_reason\":\"tool_calls\"")
    end

    it "passes raw stream payloads through unchanged" do
      streaming_payload = payload.merge(stream: true)
      raw_chunks = ["data: {\"demo\":true}\n\n", "data: [DONE]\n\n"]
      response =
        style_for([{ raw_stream: raw_chunks }]).request(
          build_request(uri, streaming_payload.to_json),
        )

      yielded = []
      response.read_body { |chunk| yielded << chunk }
      expect(yielded).to eq(raw_chunks)
    end
  end

  describe DiscourseAi::Completions::Scripted::BedrockAnthropicApiStyle do
    let(:uri) { URI("https://bedrock-runtime.test/model/anthropic-scripted/invoke") }
    let(:stream_uri) do
      URI("https://bedrock-runtime.test/model/anthropic-scripted/invoke-with-response-stream")
    end
    let(:payload) do
      {
        model: bedrock_claude_model.name,
        system: "You are helpful",
        messages: [{ role: "user", content: "Hello?" }],
      }
    end

    def style_for(responses)
      DiscourseAi::Completions::Scripted::BedrockAnthropicApiStyle.new(
        Array.wrap(responses),
        bedrock_claude_model,
      )
    end

    it "behaves like Anthropic for non-streaming requests" do
      response = style_for(["Hi via Bedrock"]).request(build_request(uri, payload.to_json))

      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:content].first).to eq({ type: "text", text: "Hi via Bedrock" })
      expect(body[:stop_reason]).to eq("end_turn")
    end

    it "wraps streaming responses inside AWS event streams" do
      streaming_payload = payload.merge(stream: true)
      response =
        style_for(["Streaming via Bedrock"]).request(
          build_request(stream_uri, streaming_payload.to_json),
        )

      chunks = []
      response.read_body { |chunk| chunks << chunk }

      decoded = decode_event_stream_chunks(chunks)

      expect(decoded.first["type"]).to eq("message_start")
      expect(decoded.any? { |entry| entry["type"] == "content_block_delta" }).to eq(true)
      stop_event = decoded.last
      expect(stop_event["type"]).to eq("message_stop")
      expect(stop_event["amazon-bedrock-invocationMetrics"]).to include("outputTokenCount")
    end
  end

  describe DiscourseAi::Completions::Scripted::BedrockNovaApiStyle do
    let(:uri) { URI("https://bedrock-runtime.test/model/nova-scripted/invoke") }
    let(:stream_uri) do
      URI("https://bedrock-runtime.test/model/nova-scripted/invoke-with-response-stream")
    end
    let(:payload) do
      {
        system: [{ text: "You are helpful" }],
        messages: [{ role: "user", content: [{ text: "Hello Nova?" }] }],
      }
    end

    def style_for(responses)
      DiscourseAi::Completions::Scripted::BedrockNovaApiStyle.new(
        Array.wrap(responses),
        bedrock_nova_model,
      )
    end

    it "produces Nova message payloads" do
      response = style_for(["Hi Nova"]).request(build_request(uri, payload.to_json))

      body = JSON.parse(response.body)
      expect(body.dig("output", "message", "content", 0, "text")).to eq("Hi Nova")
      expect(body["stopReason"]).to eq("end_turn")
      expect(body["usage"]).to include("inputTokens", "outputTokens")
    end

    it "streams Nova responses via AWS event streams" do
      response = style_for(["Streaming Nova"]).request(build_request(stream_uri, payload.to_json))

      chunks = []
      response.read_body { |chunk| chunks << chunk }
      decoded = decode_event_stream_chunks(chunks)

      expect(decoded.first["messageStart"]).to be_present
      deltas = decoded.select { |entry| entry["contentBlockDelta"] }
      expect(deltas).not_to be_empty
      metadata = decoded.last
      expect(metadata["amazon-bedrock-invocationMetrics"]).to include("inputTokenCount")
    end

    it "streams native tool calls" do
      tool_call = { tool_calls: [{ name: "lookup_time", arguments: { timezone: "UTC" } }] }
      response = style_for([tool_call]).request(build_request(stream_uri, payload.to_json))

      chunks = []
      response.read_body { |chunk| chunks << chunk }
      decoded = decode_event_stream_chunks(chunks)

      start_event = decoded.find { |entry| entry.dig("contentBlockStart", "start", "toolUse") }

      expect(start_event["contentBlockStart"]["start"]["toolUse"]["name"]).to eq("lookup_time")

      tool_delta_chunks =
        decoded
          .select { |entry| entry.dig("contentBlockDelta", "delta", "toolUse", "input") }
          .map { |entry| entry.dig("contentBlockDelta", "delta", "toolUse", "input") }

      expect(tool_delta_chunks.join).to include("UTC")
    end
  end

  describe DiscourseAi::Completions::Scripted::GeminiApiStyle do
    let(:generate_uri) { URI("#{gemini_model.url}:generateContent?key=test") }
    let(:stream_uri) { URI("#{gemini_model.url}:streamGenerateContent?alt=sse&key=test") }
    let(:payload) do
      {
        contents: [{ role: "user", parts: [{ text: "Hello?" }] }],
        generationConfig: {
        },
        safetySettings: [],
      }
    end

    def style_for(responses)
      DiscourseAi::Completions::Scripted::GeminiApiStyle.new(Array.wrap(responses), gemini_model)
    end

    it "produces Gemini message payloads" do
      response = style_for(["Hi there"]).request(build_request(generate_uri, payload.to_json))

      body = JSON.parse(response.body, symbolize_names: true)
      expect(body.dig(:candidates, 0, :content, :parts, 0, :text)).to eq("Hi there")
      expect(body.dig(:candidates, 0, :finishReason)).to eq("STOP")
      expect(body[:usageMetadata]).to include(:promptTokenCount, :candidatesTokenCount)
    end

    it "streams Gemini messages via SSE" do
      response =
        style_for(["Streaming Gemini response"]).request(build_request(stream_uri, payload.to_json))

      chunks = []
      response.read_body { |chunk| chunks << chunk }

      expect(chunks.length).to be > 1
      expect(chunks.first).to start_with("data: ")
      expect(chunks.last).to include("\"finishReason\":\"STOP\"")
      expect(chunks.last).to include("\"usageMetadata\"")
    end

    it "returns tool call payloads" do
      tool_call = { tool_calls: [{ name: "lookup_weather", arguments: { location: "CDG" } }] }
      response = style_for([tool_call]).request(build_request(generate_uri, payload.to_json))

      body = JSON.parse(response.body, symbolize_names: true)
      part = body.dig(:candidates, 0, :content, :parts, 0, :functionCall)

      expect(part).to eq({ name: "lookup_weather", args: { location: "CDG" } })
    end

    it "streams tool call payloads" do
      tool_call = { tool_calls: [{ name: "lookup_weather", arguments: { location: "CDG" } }] }
      response = style_for([tool_call]).request(build_request(stream_uri, payload.to_json))

      chunks = []
      response.read_body { |chunk| chunks << chunk }

      expect(chunks.first).to include("\"functionCall\"")
      expect(chunks.last).to include("\"usageMetadata\"")
    end

    it "passes raw stream payloads through unchanged" do
      raw_chunks = ["data: {\"candidates\":[]}\n\n"]
      response =
        style_for([{ raw_stream: raw_chunks }]).request(
          build_request(generate_uri, payload.to_json),
        )

      yielded = []
      response.read_body { |chunk| yielded << chunk }
      expect(yielded).to eq(raw_chunks)
    end
  end

  describe DiscourseAi::Completions::Scripted::AnthropicApiStyle do
    let(:uri) { URI(anthropic_model.url) }
    let(:payload) do
      {
        model: anthropic_model.name,
        system: "You are helpful",
        messages: [{ role: "user", content: "Hello?" }],
      }
    end

    def style_for(responses)
      DiscourseAi::Completions::Scripted::AnthropicApiStyle.new(
        Array.wrap(responses),
        anthropic_model,
      )
    end

    it "produces Anthropic message payloads" do
      response = style_for(["Hi there"]).request(build_request(uri, payload.to_json))

      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:role]).to eq("assistant")
      expect(body[:content].first).to eq({ type: "text", text: "Hi there" })
      expect(body[:stop_reason]).to eq("end_turn")
      expect(body[:usage]).to include(:input_tokens, :output_tokens)
    end

    it "streams Anthropic messages via event stream chunks" do
      streaming_payload = payload.merge(stream: true)
      response =
        style_for(["Streaming response"]).request(build_request(uri, streaming_payload.to_json))

      chunks = []
      response.read_body { |chunk| chunks << chunk }

      expect(chunks.first).to include("event: message_start")
      expect(chunks.grep(/event: content_block_delta/)).not_to be_empty
      expect(chunks.last).to include("event: message_stop")
    end

    it "returns tool call payloads including preamble text" do
      scripted = {
        content: "Let me call a tool",
        tool_calls: [{ id: "toolu_abc", name: "lookup_weather", arguments: { city: "Paris" } }],
      }

      response = style_for([scripted]).request(build_request(uri, payload.to_json))

      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:content].first).to eq({ type: "text", text: "Let me call a tool" })

      tool_block = body[:content].last
      expect(tool_block[:type]).to eq("tool_use")
      expect(tool_block[:name]).to eq("lookup_weather")
      expect(tool_block[:input]).to eq({ city: "Paris" })
      expect(body[:stop_reason]).to eq("tool_use")
    end

    it "streams tool call payloads" do
      scripted = {
        tool_calls: [
          { id: "toolu_weather", name: "lookup_weather", arguments: { city: "Berlin" } },
        ],
      }

      streaming_payload = payload.merge(stream: true)
      response = style_for([scripted]).request(build_request(uri, streaming_payload.to_json))

      chunks = []
      response.read_body { |chunk| chunks << chunk }

      expect(chunks.grep(/content_block_start/).first).to include("\"tool_use\"")
      expect(chunks.grep(/input_json_delta/)).not_to be_empty

      final_chunks = chunks.last(2)
      expect(final_chunks.first).to include("\"stop_reason\":\"tool_use\"")
      expect(final_chunks.last).to include("{\"type\":\"message_stop\"}")
    end

    it "passes raw stream payloads through unchanged" do
      streaming_payload = payload.merge(stream: true)
      raw_chunks = ["event: ping\ndata: {\"type\":\"ping\"}\n\n"]
      response =
        style_for([{ raw_stream: raw_chunks }]).request(
          build_request(uri, streaming_payload.to_json),
        )

      yielded = []
      response.read_body { |chunk| yielded << chunk }
      expect(yielded).to eq(raw_chunks)
    end
  end

  describe "#last_request" do
    it "captures the most recent request body" do
      client = described_class.for(llm_model: open_ai_model, responses: ["ack"])
      uri = URI(open_ai_model.url)
      request =
        build_request(
          uri,
          { model: open_ai_model.name, messages: [{ role: "user", content: "Ping" }] }.to_json,
        )

      client.start(
        uri.host,
        uri.port,
        use_ssl: true,
        read_timeout: 5,
        open_timeout: 5,
        write_timeout: 5,
      ) { |strategy| strategy.request(request) }

      expect(client.last_request.dig("messages", 0, "content")).to eq("Ping")
    end
  end

  describe DiscourseAi::Completions::Scripted::VllmApiStyle do
    let(:uri) { URI(vllm_model.url) }
    let(:payload) do
      { model: vllm_model.name, messages: [{ role: "user", content: "Hello vLLM?" }] }
    end

    def style_for(responses)
      DiscourseAi::Completions::Scripted::VllmApiStyle.new(Array.wrap(responses), vllm_model)
    end

    it "streams usage metadata with every chunk" do
      streaming_payload = payload.merge(stream: true)
      responses = [
        {
          content: "Hello Sam. Nice to meet you.",
          usage: {
            prompt_tokens: 12,
            completion_tokens: 7,
            total_tokens: 19,
          },
        },
      ]

      response = style_for(responses).request(build_request(uri, streaming_payload.to_json))

      chunks = []
      response.read_body { |chunk| chunks << chunk }

      payloads =
        chunks
          .map do |chunk|
            data_line = chunk.split("\n").find { |line| line.start_with?("data: ") }
            JSON.parse(data_line.sub("data: ", "")) if data_line
          end
          .compact

      expect(payloads.length).to be > 1
      expect(
        payloads.all? do |payload|
          payload["usage"] ==
            { "prompt_tokens" => 12, "completion_tokens" => 7, "total_tokens" => 19 }
        end,
      ).to eq(true)
    end
  end
end
