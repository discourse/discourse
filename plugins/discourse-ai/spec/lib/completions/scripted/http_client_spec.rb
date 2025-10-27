# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Scripted::HttpClient do
  fab!(:user)
  fab!(:open_ai_model, :llm_model)
  fab!(:gemini_model, :gemini_model)

  before { enable_current_plugin }

  def build_request(uri, body)
    Net::HTTP::Post.new(uri).tap { |request| request.body = body }
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
end
