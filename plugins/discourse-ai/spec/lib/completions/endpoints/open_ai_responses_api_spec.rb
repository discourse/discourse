# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::OpenAi do
  subject(:endpoint) { described_class.new(model) }

  fab!(:model) do
    Fabricate(
      :llm_model,
      provider: "open_ai",
      url: "https://api.openai.com/v1/responses",
      provider_params: {
        enable_responses_api: true,
      },
    )
  end

  let(:prompt_with_tools) do
    prompt = DiscourseAi::Completions::Prompt.new("echo: Hello")
    prompt.tools = [
      DiscourseAi::Completions::ToolDefinition.new(
        name: "echo",
        description: "Used for testing of llms, will echo the param given to it",
        parameters: [
          DiscourseAi::Completions::ToolDefinition::ParameterDefinition.from_hash(
            { name: "string", description: "string to echo", type: :string, required: true },
          ),
        ],
      ),
    ]
    prompt
  end

  def with_scripted_responses(responses, &block)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      responses,
      llm: model,
      transport: :scripted_http,
      &block
    )
  end

  before { enable_current_plugin }

  it "can retain thinking tokens during streaming completions" do
    partials = []

    request_payload = nil

    scripted_response = {
      content: "hello",
      text_chunks: ["hello"],
      message_id: "msg_0e7bcfab8fc907240069152d1173f48192a1f37340a24e4fba",
      reasoning: {
        id: "rs_0391d4281ead19e40069142428f734819da32f5c13bd277a25",
        encrypted_content: "ABC",
        deltas: %w[**Craft ing],
        summary: "**Crafting",
      },
      usage: {
        input_tokens: 26,
        input_tokens_details: {
          cached_tokens: 0,
        },
        output_tokens: 7,
        output_tokens_details: {
          reasoning_tokens: 0,
        },
        total_tokens: 33,
      },
    }

    with_scripted_responses([scripted_response]) do |scripted_http|
      model
        .to_llm
        .generate(
          "Say: Hello World",
          user: Discourse.system_user,
          output_thinking: true,
        ) { |partial| partials << partial }

      request_payload = scripted_http.last_request.deep_symbolize_keys
    end

    expect(request_payload[:include]).to eq(["reasoning.encrypted_content"])
    expect(request_payload.dig(:reasoning, :summary)).to eq("auto")

    expect(partials.length).to eq(4)

    expect(partials[0]).to eq(
      DiscourseAi::Completions::Thinking.new(message: "**Craft", partial: true),
    )

    expect(partials[1]).to eq(DiscourseAi::Completions::Thinking.new(message: "ing", partial: true))
    final_thinking =
      DiscourseAi::Completions::Thinking.new(
        message: "**Crafting",
        partial: false,
        provider_info: {
          open_ai_responses: {
            reasoning_id: "rs_0391d4281ead19e40069142428f734819da32f5c13bd277a25",
            encrypted_content: "ABC",
            next_message_id: "msg_0e7bcfab8fc907240069152d1173f48192a1f37340a24e4fba",
          },
        },
      )
    expect(partials[2]).to eq(final_thinking)
    expect(partials[2].provider_info[:open_ai_responses]).to include(
      reasoning_id: "rs_0391d4281ead19e40069142428f734819da32f5c13bd277a25",
      next_message_id: "msg_0e7bcfab8fc907240069152d1173f48192a1f37340a24e4fba",
    )
    expect(partials[3]).to eq("hello")

    log = AiApiAuditLog.last

    expect(log).to be_present
    expect(log.request_tokens).to eq(26)
    expect(log.response_tokens).to eq(7)
    expect(log.cached_tokens).to eq(0)
  end

  it "can perform simple streaming completion" do
    partials = []

    scripted_response = {
      content: "Hello World",
      text_chunks: ["Hello", " ", "World"],
      usage: {
        input_tokens: 35,
        input_tokens_details: {
          cached_tokens: 5,
        },
        output_tokens: 9,
        output_tokens_details: {
          reasoning_tokens: 0,
        },
        total_tokens: 37,
      },
    }

    with_scripted_responses([scripted_response]) do
      model
        .to_llm
        .generate("Say: Hello World", user: Discourse.system_user) { |partial| partials << partial }
    end

    expect(partials).to eq(["Hello", " ", "World"])

    log = AiApiAuditLog.last

    # note: our report counts cache and request tokens separately see: DiscourseAi::Completions::Report
    expect(log).to be_present
    expect(log.request_tokens).to eq(30)
    expect(log.response_tokens).to eq(9)
    expect(log.cached_tokens).to eq(5)
  end

  it "can properly stream tool calls" do
    partials = []

    scripted_response = {
      tool_calls: [
        { id: "call_TQyfNmFnKblzXl5rlcGeIsg5", name: "echo", arguments: '{"string":"hello"}' },
      ],
      usage: {
        input_tokens: 71,
        input_tokens_details: {
          cached_tokens: 0,
        },
        output_tokens: 6,
        output_tokens_details: {
          reasoning_tokens: 0,
        },
        total_tokens: 77,
      },
    }

    with_scripted_responses([scripted_response]) do
      model
        .to_llm
        .generate(
          prompt_with_tools,
          user: Discourse.system_user,
          partial_tool_calls: true,
        ) { |partial| partials << partial.dup }
    end

    tool_partials = partials.grep(DiscourseAi::Completions::ToolCall)

    expect(tool_partials).not_to be_empty
    final_call = tool_partials.last

    expect(final_call).to be_a(DiscourseAi::Completions::ToolCall)
    expect(final_call.name).to eq("echo")
    expect(final_call.parameters).to eq({ string: "hello" })
    expect(final_call.id).to eq("call_TQyfNmFnKblzXl5rlcGeIsg5")
  end

  it "can handle non streaming tool calls" do
    scripted_response = {
      tool_calls: [
        { id: "call_UdxBpinIVc5nRZ0VnWJIgneA", name: "echo", arguments: '{"string":"sam"}' },
      ],
      usage: {
        input_tokens: 73,
        input_tokens_details: {
          cached_tokens: 0,
        },
        output_tokens: 6,
        output_tokens_details: {
          reasoning_tokens: 0,
        },
        total_tokens: 79,
      },
    }

    result =
      with_scripted_responses([scripted_response]) do
        model.to_llm.generate(prompt_with_tools, user: Discourse.system_user)
      end

    expect(result).to be_a(DiscourseAi::Completions::ToolCall)
    expect(result.name).to eq("echo")
    expect(result.parameters).to eq({ string: "sam" })
    expect(result.id).to eq("call_UdxBpinIVc5nRZ0VnWJIgneA")
  end
end
