# frozen_string_literal: true

require_relative "endpoint_compliance"

class VllmMock < EndpointMock
  def response(content)
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
        { message: { role: "assistant", content: content }, finish_reason: "stop", index: 0 },
      ],
    }
  end

  def stub_response(prompt, response_text, tool_call: false)
    WebMock
      .stub_request(:post, "https://test.dev/v1/chat/completions")
      .with(body: model.default_options.merge(messages: prompt).to_json)
      .to_return(status: 200, body: JSON.dump(response(response_text)))
  end

  def stream_line(delta, finish_reason: nil)
    +"data: " << {
      id: "cmpl-#{SecureRandom.hex}",
      created: 1_681_283_881,
      model: "mistralai/Mixtral-8x7B-Instruct-v0.1",
      choices: [{ delta: { content: delta } }],
      index: 0,
    }.to_json
  end

  def stub_streamed_response(prompt, deltas, tool_call: false)
    chunks =
      deltas.each_with_index.map do |_, index|
        if index == (deltas.length - 1)
          stream_line(deltas[index], finish_reason: "stop_sequence")
        else
          stream_line(deltas[index])
        end
      end

    chunks = (chunks.join("\n\n") << "data: [DONE]").split("")

    WebMock
      .stub_request(:post, "https://test.dev/v1/chat/completions")
      .with(
        body:
          model
            .default_options
            .merge(messages: prompt, stream: true, stream_options: { include_usage: true })
            .to_json,
      )
      .to_return(status: 200, body: chunks)
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

  before { enable_current_plugin }

  describe "tool support" do
    it "is able to invoke XML tools correctly" do
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
    body = (<<~TEXT).strip
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
end
