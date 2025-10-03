# frozen_string_literal: true

require_relative "endpoint_compliance"

class OllamaMock < EndpointMock
  def response(content, tool_call: false)
    message_content =
      if tool_call
        { content: "", tool_calls: [content] }
      else
        { content: content }
      end

    {
      created_at: "2024-09-25T06:47:21.283028Z",
      model: "llama3.1",
      message: { role: "assistant" }.merge(message_content),
      done: true,
      done_reason: "stop",
      total_duration: 7_639_718_541,
      load_duration: 299_886_663,
      prompt_eval_count: 18,
      prompt_eval_duration: 220_447_000,
      eval_count: 18,
      eval_duration: 220_447_000,
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "http://api.ollama.ai/api/chat")
      .with(body: request_body(prompt, tool_call: tool_call))
      .to_return(status: 200, body: JSON.dump(response(response_text, tool_call: tool_call)))
  end

  def stream_line(delta)
    message_content = { content: delta }

    +{
      model: "llama3.1",
      created_at: "2024-09-25T06:47:21.283028Z",
      message: { role: "assistant" }.merge(message_content),
      done: false,
    }.to_json
  end

  def stub_raw(chunks)
    WebMock.stub_request(:post, "http://api.ollama.ai/api/chat").to_return(
      status: 200,
      body: chunks,
    )
  end

  def stub_streamed_response(prompt, deltas)
    chunks = deltas.each_with_index.map { |_, index| stream_line(deltas[index]) }

    chunks =
      (
        chunks.join("\n\n") << {
          model: "llama3.1",
          created_at: "2024-09-25T06:47:21.283028Z",
          message: {
            role: "assistant",
            content: "",
          },
          done: true,
          done_reason: "stop",
          total_duration: 7_639_718_541,
          load_duration: 299_886_663,
          prompt_eval_count: 18,
          prompt_eval_duration: 220_447_000,
          eval_count: 18,
          eval_duration: 220_447_000,
        }.to_json
      ).split("")

    WebMock
      .stub_request(:post, "http://api.ollama.ai/api/chat")
      .with(body: request_body(prompt))
      .to_return(status: 200, body: chunks)

    yield if block_given?
  end

  def tool_response
    { function: { name: "get_weather", arguments: { location: "Sydney", unit: "c" } } }
  end

  def tool_payload
    {
      type: "function",
      function: {
        name: "get_weather",
        description: "Get the weather in a city",
        parameters: {
          type: "object",
          properties: {
            location: {
              type: "string",
              description: "the city name",
            },
            unit: {
              type: "string",
              description: "the unit of measurement celcius c or fahrenheit f",
              enum: %w[c f],
            },
          },
          required: %w[location unit],
        },
      },
    }
  end

  def request_body(prompt, tool_call: false)
    model
      .default_options
      .merge(messages: prompt)
      .tap do |b|
        b[:stream] = false
        b[:tools] = [tool_payload] if tool_call
      end
      .to_json
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::Ollama do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)
  fab!(:model) { Fabricate(:ollama_model) }

  let(:ollama_mock) { OllamaMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Ollama, user)
  end

  before { enable_current_plugin }

  describe "#perform_completion!" do
    context "when using regular mode" do
      it "completes a trivial prompt and logs the response" do
        compliance.regular_mode_simple_prompt(ollama_mock)
      end
    end

    context "with tools" do
      it "returns a function invocation" do
        compliance.regular_mode_tools(ollama_mock)
      end
    end
  end

  describe "when using streaming mode" do
    context "with simple prompts" do
      it "completes a trivial prompt and logs the response" do
        compliance.streaming_mode_simple_prompt(ollama_mock)
      end
    end
  end
end
