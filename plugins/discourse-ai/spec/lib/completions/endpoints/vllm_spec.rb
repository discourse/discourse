# frozen_string_literal: true

require_relative "endpoint_compliance"

class VllmMock < EndpointMock
  def response(content, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [content] }
      else
        { content: content }
      end

    {
      id: "cmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
      object: "chat.completion",
      created: 1_678_464_820,
      model: "mistralai/Mixtral-8x7B-Instruct-v0.1",
      usage: {
        prompt_tokens: 337,
        completion_tokens: 162,
        total_tokens: 499,
      },
      choices: [
        { message: { role: "assistant" }.merge(message_content), finish_reason: "stop", index: 0 },
      ],
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "https://test.dev/v1/chat/completions")
      .with(body: request_body(prompt, tool_call: tool_call))
      .to_return(status: 200, body: JSON.dump(response(response_text, tool_call: tool_call)))
  end

  def stream_line(delta, finish_reason: nil, tool_call: false)
    message_content =
      if tool_call
        { tool_calls: [delta] }
      else
        { content: delta }
      end

    +"data: " << {
      id: "cmpl-#{SecureRandom.hex}",
      object: "chat.completion.chunk",
      created: 1_681_283_881,
      model: "mistralai/Mixtral-8x7B-Instruct-v0.1",
      choices: [{ delta: message_content }],
      finish_reason: finish_reason,
      index: 0,
    }.to_json
  end

  def stub_streamed_response(prompt, deltas, tool_call: false)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "stop_sequence", tool_call: tool_call)
        else
          stream_line(deltas[index], tool_call: tool_call)
        end
      end

    chunks = (chunks.join("\n\n") << "data: [DONE]").split("")

    WebMock
      .stub_request(:post, "https://test.dev/v1/chat/completions")
      .with(body: request_body(prompt, stream: true, tool_call: tool_call))
      .to_return(status: 200, body: chunks)
  end

  def tool_deltas
    [
      { id: tool_id, function: {} },
      { id: tool_id, function: { name: "get_weather", arguments: "" } },
      { id: tool_id, function: { arguments: "" } },
      { id: tool_id, function: { arguments: "{" } },
      { id: tool_id, function: { arguments: " \"location\": \"Sydney\"" } },
      { id: tool_id, function: { arguments: " ,\"unit\": \"c\" }" } },
    ]
  end

  def tool_response
    {
      id: tool_id,
      function: {
        name: "get_weather",
        arguments: { location: "Sydney", unit: "c" }.to_json,
      },
    }
  end

  def tool_id
    "tool_0"
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

  def request_body(prompt, stream: false, tool_call: false)
    model
      .default_options
      .merge(messages: prompt)
      .tap do |body|
        body[:stream] = true if stream
        body[:tools] = [tool_payload] if tool_call
        body[:stream_options] = { include_usage: true } if stream
      end
      .to_json
  end
end

RSpec.describe DiscourseAi::Completions::Endpoints::Vllm do
  subject(:endpoint) { described_class.new(llm_model) }

  fab!(:llm_model, :vllm_model)
  fab!(:user)

  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:vllm_mock) { VllmMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(
      self,
      endpoint,
      DiscourseAi::Completions::Dialects::OpenAiCompatible,
      user,
    )
  end

  let(:dialect) do
    DiscourseAi::Completions::Dialects::OpenAiCompatible.new(generic_prompt, llm_model)
  end
  let(:prompt) { dialect.translate }

  let(:request_body) { model.default_options.merge(messages: prompt).to_json }
  let(:stream_request_body) { model.default_options.merge(messages: prompt, stream: true).to_json }
  let(:completion_response_body) do
    {
      choices: [{ message: { role: "assistant", content: "hello" } }],
      usage: {
        prompt_tokens: 10,
        completion_tokens: 5,
      },
    }.to_json
  end

  before { enable_current_plugin }

  def capture_payload_for_completion
    captured_payload = nil
    stub =
      stub_request(:post, "https://test.dev/v1/chat/completions")
        .with do |request|
          captured_payload = JSON.parse(request.body)
          true
        end
        .to_return(status: 200, body: completion_response_body)

    llm.generate("say hello", user: Discourse.system_user)

    expect(stub).to have_been_requested
    captured_payload
  end

  describe "tool support" do
    it "is able to invoke XML tools correctly" do
      llm_model.update!(provider_params: { "disable_native_tools" => true })

      xml = <<~XML
        <function_calls>
        <invoke>
        <tool_name>calculate</tool_name>
        <parameters>
        <expression>1+1</expression></parameters>
        </invoke>
        </function_calls>
        should be ignored
      XML

      body = {
        id: "chatcmpl-6sZfAb30Rnv9Q7ufzFwvQsMpjZh8S",
        object: "chat.completion",
        created: 1_678_464_820,
        model: "gpt-3.5-turbo-0301",
        usage: {
          prompt_tokens: 337,
          completion_tokens: 162,
          total_tokens: 499,
        },
        choices: [
          { message: { role: "assistant", content: xml }, finish_reason: "stop", index: 0 },
        ],
      }
      tool = {
        name: "calculate",
        description: "calculate something",
        parameters: [
          {
            name: "expression",
            type: "string",
            description: "expression to calculate",
            required: true,
          },
        ],
      }

      stub_request(:post, "https://test.dev/v1/chat/completions").to_return(
        status: 200,
        body: body.to_json,
      )

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You a calculator",
          messages: [{ type: :user, id: "user1", content: "calculate 2758975 + 21.11" }],
          tools: [tool],
        )

      result = llm.generate(prompt, user: Discourse.system_user)

      expected =
        DiscourseAi::Completions::ToolCall.new(
          name: "calculate",
          id: "tool_0",
          parameters: {
            expression: "1+1",
          },
        )

      expect(result).to eq(expected)
    end
  end

  it "correctly accounts for tokens in non streaming mode" do
    body = <<~TEXT.strip
      {"id":"chat-c580e4a9ebaa44a0becc802ed5dc213a","object":"chat.completion","created":1731294404,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"message":{"role":"assistant","content":"Random Number Generator Produces Smallest Possible Result","tool_calls":[]},"logprobs":null,"finish_reason":"stop","stop_reason":null}],"usage":{"prompt_tokens":146,"total_tokens":156,"completion_tokens":10},"prompt_logprobs":null}
    TEXT

    stub_request(:post, "https://test.dev/v1/chat/completions").to_return(status: 200, body: body)

    result = llm.generate("generate a title", user: Discourse.system_user)

    expect(result).to eq("Random Number Generator Produces Smallest Possible Result")

    log = AiApiAuditLog.order(:id).last
    expect(log.request_tokens).to eq(146)
    expect(log.response_tokens).to eq(10)
  end

  it "can properly include usage in streaming mode" do
    payload = <<~TEXT.strip
      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"role":"assistant","content":""},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":46,"completion_tokens":0}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":"Hello"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":47,"completion_tokens":1}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" Sam"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":48,"completion_tokens":2}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":"."},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":49,"completion_tokens":3}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" It"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":50,"completion_tokens":4}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":"'s"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":51,"completion_tokens":5}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" nice"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":52,"completion_tokens":6}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" to"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":53,"completion_tokens":7}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" meet"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":54,"completion_tokens":8}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" you"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":55,"completion_tokens":9}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":"."},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":56,"completion_tokens":10}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" Is"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":57,"completion_tokens":11}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" there"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":58,"completion_tokens":12}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" something"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":59,"completion_tokens":13}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" I"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":60,"completion_tokens":14}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" can"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":61,"completion_tokens":15}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" help"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":62,"completion_tokens":16}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" you"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":63,"completion_tokens":17}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" with"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":64,"completion_tokens":18}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" or"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":65,"completion_tokens":19}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" would"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":66,"completion_tokens":20}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" you"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":67,"completion_tokens":21}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" like"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":68,"completion_tokens":22}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" to"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":69,"completion_tokens":23}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":" chat"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":70,"completion_tokens":24}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":"?"},"logprobs":null,"finish_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":71,"completion_tokens":25}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[{"index":0,"delta":{"content":""},"logprobs":null,"finish_reason":"stop","stop_reason":null}],"usage":{"prompt_tokens":46,"total_tokens":72,"completion_tokens":26}}

      data: {"id":"chat-b183bb5829194e8891cacceabfdb5274","object":"chat.completion.chunk","created":1731295402,"model":"meta-llama/Meta-Llama-3.1-70B-Instruct","choices":[],"usage":{"prompt_tokens":46,"total_tokens":72,"completion_tokens":26}}

      data: [DONE]
    TEXT

    stub_request(:post, "https://test.dev/v1/chat/completions").to_return(
      status: 200,
      body: payload,
    )

    response = []
    llm.generate("say hello", user: Discourse.system_user) { |partial| response << partial }

    expect(response.join).to eq(
      "Hello Sam. It's nice to meet you. Is there something I can help you with or would you like to chat?",
    )

    log = AiApiAuditLog.order(:id).last
    expect(log.request_tokens).to eq(46)
    expect(log.response_tokens).to eq(26)
  end

  describe "thinking controls" do
    it "sends enable_thinking for Qwen thinking overrides" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "qwen3",
          "thinking_override" => "off",
        },
      )

      payload = capture_payload_for_completion
      expect(payload["chat_template_kwargs"]).to eq("enable_thinking" => false)
    end

    it "sends enable_thinking for Gemma thinking overrides" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "gemma4",
          "thinking_override" => "on",
        },
      )

      payload = capture_payload_for_completion
      expect(payload["chat_template_kwargs"]).to eq("enable_thinking" => true)
    end

    it "sends enable_thinking for DeepSeek V4 thinking overrides" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "deepseek_v4",
          "thinking_override" => "on",
        },
      )

      payload = capture_payload_for_completion
      expect(payload["chat_template_kwargs"]).to eq("enable_thinking" => true)
    end

    it "sends thinking for Granite thinking overrides" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "granite",
          "thinking_override" => "on",
        },
      )

      payload = capture_payload_for_completion
      expect(payload["chat_template_kwargs"]).to eq("thinking" => true)
    end

    it "sends thinking for DeepSeek V3 thinking overrides" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "deepseek_v3",
          "thinking_override" => "off",
        },
      )

      payload = capture_payload_for_completion
      expect(payload["chat_template_kwargs"]).to eq("thinking" => false)
    end

    it "sends thinking for Holo thinking overrides" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "holo2",
          "thinking_override" => "off",
        },
      )

      payload = capture_payload_for_completion
      expect(payload["chat_template_kwargs"]).to eq("thinking" => false)
    end

    it "keeps DeepSeek R1 thinking on the server default" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "deepseek_r1",
          "thinking_override" => "off",
        },
      )

      payload = capture_payload_for_completion
      expect(payload).not_to have_key("chat_template_kwargs")
    end

    it "keeps legacy enable_thinking behavior" do
      llm_model.update!(provider_params: { "enable_thinking" => true })

      payload = capture_payload_for_completion
      expect(payload["chat_template_kwargs"]).to eq("enable_thinking" => true)
    end

    it "prefers thinking_override over legacy enable_thinking" do
      llm_model.update!(
        provider_params: {
          "enable_thinking" => true,
          "reasoning_parser" => "qwen3",
          "thinking_override" => "off",
        },
      )

      payload = capture_payload_for_completion
      expect(payload["chat_template_kwargs"]).to eq("enable_thinking" => false)
    end

    it "sends a positive thinking_token_budget with a parser" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "qwen3",
          "thinking_token_budget" => "1024",
        },
      )

      payload = capture_payload_for_completion
      expect(payload["thinking_token_budget"]).to eq(1024)
    end

    it "ignores thinking_token_budget without active reasoning" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "default",
          "thinking_token_budget" => "1024",
        },
      )

      payload = capture_payload_for_completion
      expect(payload).not_to have_key("thinking_token_budget")
    end

    it "ignores non-positive thinking_token_budget values" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "qwen3",
          "thinking_token_budget" => "0",
        },
      )

      payload = capture_payload_for_completion
      expect(payload).not_to have_key("thinking_token_budget")
    end

    it "ignores thinking_token_budget with reasoning_effort none" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "qwen3",
          "reasoning_effort" => "none",
          "thinking_token_budget" => "1024",
        },
      )

      payload = capture_payload_for_completion
      expect(payload).not_to have_key("thinking_token_budget")
    end

    it "sends supported vLLM reasoning_effort values" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "qwen3",
          "reasoning_effort" => "high",
        },
      )

      payload = capture_payload_for_completion
      expect(payload["reasoning_effort"]).to eq("high")
    end

    it "keeps existing reasoning_effort without a parser" do
      llm_model.update!(provider_params: { "reasoning_effort" => "high" })

      payload = capture_payload_for_completion
      expect(payload["reasoning_effort"]).to eq("high")
    end

    it "ignores unsupported vLLM reasoning_effort values" do
      llm_model.update!(
        provider_params: {
          "reasoning_parser" => "qwen3",
          "reasoning_effort" => "xhigh",
        },
      )

      payload = capture_payload_for_completion
      expect(payload).not_to have_key("reasoning_effort")
    end
  end

  describe "stream_options" do
    it "includes stream_options with include_usage in streaming mode" do
      stub =
        stub_request(:post, "https://test.dev/v1/chat/completions").with(
          body: hash_including("stream_options" => { "include_usage" => true }),
        ).to_return(
          status: 200,
          body: +"data: #{{ choices: [{ delta: { content: "hello" } }] }.to_json}\n\ndata: [DONE]",
        )

      llm.generate("say hello", user: Discourse.system_user) { |_| }

      expect(stub).to have_been_requested
    end
  end

  describe "reasoning" do
    it "returns Thinking and content for non-streaming response with output_thinking" do
      body = {
        choices: [
          {
            message: {
              role: "assistant",
              content: "The answer is 4.",
              reasoning: "Let me think step by step: 2+2=4",
            },
          },
        ],
        usage: {
          prompt_tokens: 10,
          completion_tokens: 20,
        },
      }

      stub_request(:post, "https://test.dev/v1/chat/completions").to_return(
        status: 200,
        body: body.to_json,
      )

      result = llm.generate("what is 2+2?", user: Discourse.system_user, output_thinking: true)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)

      thinking = result[0]
      expect(thinking).to be_a(DiscourseAi::Completions::Thinking)
      expect(thinking.message).to eq("Let me think step by step: 2+2=4")
      expect(thinking.partial?).to eq(false)

      expect(result[1]).to eq("The answer is 4.")
    end

    it "streams Thinking partials followed by content" do
      chunks = []

      chunks << "data: #{({ choices: [{ delta: { role: "assistant", reasoning: "Let me " } }] }).to_json}\n\n"
      chunks << "data: #{({ choices: [{ delta: { reasoning: "think." } }] }).to_json}\n\n"
      chunks << "data: #{({ choices: [{ delta: { content: "The answer" } }] }).to_json}\n\n"
      chunks << "data: #{({ choices: [{ delta: { content: " is 4." } }], usage: { prompt_tokens: 10, completion_tokens: 20 } }).to_json}\n\n"
      chunks << "data: [DONE]\n\n"

      stub_request(:post, "https://test.dev/v1/chat/completions").to_return(
        status: 200,
        body: chunks.join,
      )

      partials = []
      llm.generate("what is 2+2?", user: Discourse.system_user, output_thinking: true) do |partial|
        partials << partial
      end

      thinking_partials =
        partials.select { |partial| partial.is_a?(DiscourseAi::Completions::Thinking) }
      text_partials = partials.select { |partial| partial.is_a?(String) }

      expect(thinking_partials.length).to eq(3)

      expect(thinking_partials[0].message).to eq("Let me ")
      expect(thinking_partials[0].partial?).to eq(true)

      expect(thinking_partials[1].message).to eq("think.")
      expect(thinking_partials[1].partial?).to eq(true)

      expect(thinking_partials[2].message).to eq("Let me think.")
      expect(thinking_partials[2].partial?).to eq(false)

      expect(text_partials.join).to eq("The answer is 4.")
    end
  end

  describe "reasoning_content" do
    it "returns Thinking and content for non-streaming response with output_thinking" do
      body = {
        choices: [
          {
            message: {
              role: "assistant",
              content: "The answer is 4.",
              reasoning_content: "Let me think step by step: 2+2=4",
            },
          },
        ],
        usage: {
          prompt_tokens: 10,
          completion_tokens: 20,
        },
      }

      stub_request(:post, "https://test.dev/v1/chat/completions").to_return(
        status: 200,
        body: body.to_json,
      )

      result = llm.generate("what is 2+2?", user: Discourse.system_user, output_thinking: true)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)

      thinking = result[0]
      expect(thinking).to be_a(DiscourseAi::Completions::Thinking)
      expect(thinking.message).to eq("Let me think step by step: 2+2=4")
      expect(thinking.partial?).to eq(false)

      expect(result[1]).to eq("The answer is 4.")
    end

    it "omits Thinking when output_thinking is false" do
      body = {
        choices: [
          {
            message: {
              role: "assistant",
              content: "The answer is 4.",
              reasoning_content: "Let me think step by step: 2+2=4",
            },
          },
        ],
        usage: {
          prompt_tokens: 10,
          completion_tokens: 20,
        },
      }

      stub_request(:post, "https://test.dev/v1/chat/completions").to_return(
        status: 200,
        body: body.to_json,
      )

      result = llm.generate("what is 2+2?", user: Discourse.system_user)

      expect(result).to eq("The answer is 4.")
    end

    it "streams Thinking partials followed by content" do
      chunks = []

      chunks << "data: #{({ choices: [{ delta: { role: "assistant", reasoning_content: "Let me " } }] }).to_json}\n\n"
      chunks << "data: #{({ choices: [{ delta: { reasoning_content: "think." } }] }).to_json}\n\n"
      chunks << "data: #{({ choices: [{ delta: { content: "The answer" } }] }).to_json}\n\n"
      chunks << "data: #{({ choices: [{ delta: { content: " is 4." } }], usage: { prompt_tokens: 10, completion_tokens: 20 } }).to_json}\n\n"
      chunks << "data: [DONE]\n\n"

      stub_request(:post, "https://test.dev/v1/chat/completions").to_return(
        status: 200,
        body: chunks.join,
      )

      partials = []
      llm.generate("what is 2+2?", user: Discourse.system_user, output_thinking: true) do |partial|
        partials << partial
      end

      thinking_partials =
        partials.select { |partial| partial.is_a?(DiscourseAi::Completions::Thinking) }
      text_partials = partials.select { |partial| partial.is_a?(String) }

      expect(thinking_partials.length).to eq(3)

      expect(thinking_partials[0].message).to eq("Let me ")
      expect(thinking_partials[0].partial?).to eq(true)

      expect(thinking_partials[1].message).to eq("think.")
      expect(thinking_partials[1].partial?).to eq(true)

      expect(thinking_partials[2].message).to eq("Let me think.")
      expect(thinking_partials[2].partial?).to eq(false)

      expect(text_partials.join).to eq("The answer is 4.")
    end
  end

  describe "#perform_completion!" do
    context "when using regular mode" do
      context "with tools" do
        it "returns a function invocation" do
          compliance.regular_mode_tools(vllm_mock)
        end
      end
    end

    describe "when using streaming mode" do
      context "with simple prompts" do
        it "completes a trivial prompt and logs the response" do
          compliance.streaming_mode_simple_prompt(vllm_mock)
        end
      end

      context "with tools" do
        it "returns a function invoncation" do
          compliance.streaming_mode_tools(vllm_mock)
        end
      end
    end
  end

  describe "request header providers" do
    after { described_class.reset_request_headers_providers! }

    def capture_headers(feature_name: nil)
      captured = nil
      stub =
        stub_request(:post, "https://test.dev/v1/chat/completions")
          .with do |request|
            captured = request.headers
            true
          end
          .to_return(status: 200, body: completion_response_body)

      llm.generate("say hello", user: Discourse.system_user, feature_name: feature_name)

      expect(stub).to have_been_requested
      captured
    end

    it "merges headers contributed by a registered provider" do
      described_class.register_request_headers_provider do |context|
        { "X-Test-Feature" => context.feature_name || "default" }
      end

      headers = capture_headers(feature_name: "summarize")

      expect(headers["X-Test-Feature"]).to eq("summarize")
    end

    it "passes request context (llm_model, streaming, vision) to the provider" do
      captured_context = nil
      described_class.register_request_headers_provider do |context|
        captured_context = context
        {}
      end

      capture_headers(feature_name: "ai_helper")

      expect(captured_context.llm_model).to eq(llm_model)
      expect(captured_context.feature_name).to eq("ai_helper")
      expect(captured_context.streaming).to eq(false)
      expect(captured_context.has_images).to eq(false)
    end

    it "isolates provider failures so the completion still succeeds" do
      described_class.register_request_headers_provider { |_context| raise "boom" }
      described_class.register_request_headers_provider { |_context| { "X-Test-Survivor" => "1" } }

      headers = nil
      expect { headers = capture_headers }.not_to raise_error
      expect(headers["X-Test-Survivor"]).to eq("1")
    end

    it "sends no extra headers when nothing is registered" do
      headers = capture_headers
      expect(headers.keys).not_to include("X-Test-Feature")
    end
  end

  describe "#prompt_has_images?" do
    it "is true when a message carries an image_url content part" do
      prompt = [
        { role: "user", content: [{ type: "text", text: "hi" }] },
        {
          role: "user",
          content: [{ type: "image_url", image_url: { url: "data:image/png;base64,abc" } }],
        },
      ]

      expect(endpoint.send(:prompt_has_images?, prompt)).to eq(true)
    end

    it "is false for text-only or non-array prompts" do
      expect(endpoint.send(:prompt_has_images?, [{ role: "user", content: "hi" }])).to eq(false)
      expect(endpoint.send(:prompt_has_images?, nil)).to eq(false)
    end
  end
end
