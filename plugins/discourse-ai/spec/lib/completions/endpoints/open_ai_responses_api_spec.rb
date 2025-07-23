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

  before { enable_current_plugin }

  it "can perform simple streaming completion" do
    response_payload = <<~TEXT
      event: response.created
      data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_6848d84bee44819d98e5f4f5103562090333bc932679b022","object":"response","created_at":1749604427,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"model":"gpt-4.1-nano-2025-04-14","output":[],"parallel_tool_calls":true,"previous_response_id":null,"reasoning":{"effort":null,"summary":null},"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"}},"tool_choice":"auto","tools":[],"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

      event: response.in_progress
      data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_6848d84bee44819d98e5f4f5103562090333bc932679b022","object":"response","created_at":1749604427,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"model":"gpt-4.1-nano-2025-04-14","output":[],"parallel_tool_calls":true,"previous_response_id":null,"reasoning":{"effort":null,"summary":null},"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"}},"tool_choice":"auto","tools":[],"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

      event: response.output_item.added
      data: {"type":"response.output_item.added","sequence_number":2,"output_index":0,"item":{"id":"msg_6848d84c3bc8819dace0eadec6e205090333bc932679b022","type":"message","status":"in_progress","content":[],"role":"assistant"}}

      event: response.content_part.added
      data: {"type":"response.content_part.added","sequence_number":3,"item_id":"msg_6848d84c3bc8819dace0eadec6e205090333bc932679b022","output_index":0,"content_index":0,"part":{"type":"output_text","annotations":[],"text":""}}

      event: response.output_text.delta
      data: {"type":"response.output_text.delta","sequence_number":4,"item_id":"msg_6848d84c3bc8819dace0eadec6e205090333bc932679b022","output_index":0,"content_index":0,"delta":"Hello"}

      event: response.output_text.delta
      data: {"type":"response.output_text.delta","sequence_number":5,"item_id":"msg_6848d84c3bc8819dace0eadec6e205090333bc932679b022","output_index":0,"content_index":0,"delta":" "}

      event: response.output_text.delta
      data: {"type":"response.output_text.delta","sequence_number":5,"item_id":"msg_6848d84c3bc8819dace0eadec6e205090333bc932679b022","output_index":0,"content_index":0,"delta":"World"}

      event: response.output_text.done
      data: {"type":"response.output_text.done","sequence_number":5,"item_id":"msg_6848d84c3bc8819dace0eadec6e205090333bc932679b022","output_index":0,"content_index":0,"text":"Hello World"}

      event: response.content_part.done
      data: {"type":"response.content_part.done","sequence_number":6,"item_id":"msg_6848d84c3bc8819dace0eadec6e205090333bc932679b022","output_index":0,"content_index":0,"part":{"type":"output_text","annotations":[],"text":"Hello World"}}

      event: response.output_item.done
      data: {"type":"response.output_item.done","sequence_number":7,"output_index":0,"item":{"id":"msg_6848d84c3bc8819dace0eadec6e205090333bc932679b022","type":"message","status":"completed","content":[{"type":"output_text","annotations":[],"text":"Hello World"}],"role":"assistant"}}

      event: response.completed
      data: {"type":"response.completed","sequence_number":8,"response":{"id":"resp_6848d84bee44819d98e5f4f5103562090333bc932679b022","object":"response","created_at":1749604427,"status":"completed","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"model":"gpt-4.1-nano-2025-04-14","output":[{"id":"msg_6848d84c3bc8819dace0eadec6e205090333bc932679b022","type":"message","status":"completed","content":[{"type":"output_text","annotations":[],"text":"Hello"}],"role":"assistant"}],"parallel_tool_calls":true,"previous_response_id":null,"reasoning":{"effort":null,"summary":null},"service_tier":"default","store":true,"temperature":1.0,"text":{"format":{"type":"text"}},"tool_choice":"auto","tools":[],"top_p":1.0,"truncation":"disabled","usage":{"input_tokens":35,"input_tokens_details":{"cached_tokens":5},"output_tokens":9,"output_tokens_details":{"reasoning_tokens":0},"total_tokens":37},"user":null,"metadata":{}}}
    TEXT

    partials = []

    stub_request(:post, "https://api.openai.com/v1/responses").to_return(
      status: 200,
      body: response_payload,
    )

    model
      .to_llm
      .generate("Say: Hello World", user: Discourse.system_user) { |partial| partials << partial }

    expect(partials).to eq(["Hello", " ", "World"])

    log = AiApiAuditLog.last

    # note: our report counts cache and request tokens separately see: DiscourseAi::Completions::Report
    expect(log).to be_present
    expect(log.request_tokens).to eq(30)
    expect(log.response_tokens).to eq(9)
    expect(log.cached_tokens).to eq(5)
  end

  it "can properly stream tool calls" do
    response_payload = <<~TEXT
      event: response.created
      data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_684910c81eec81a3a9222aa336d9fcf202d35c1819a50f63","object":"response","created_at":1749618888,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"model":"gpt-4.1-nano-2025-04-14","output":[],"parallel_tool_calls":true,"previous_response_id":null,"reasoning":{"effort":null,"summary":null},"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"}},"tool_choice":{"type":"function","name":"echo"},"tools":[{"type":"function","description":"Used for testing of llms, will echo the param given to it","name":"echo","parameters":{"type":"object","properties":{"string":{"type":"string","description":"string to echo"}},"required":["string"]},"strict":true}],"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

      event: response.in_progress
      data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_684910c81eec81a3a9222aa336d9fcf202d35c1819a50f63","object":"response","created_at":1749618888,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"model":"gpt-4.1-nano-2025-04-14","output":[],"parallel_tool_calls":true,"previous_response_id":null,"reasoning":{"effort":null,"summary":null},"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"}},"tool_choice":{"type":"function","name":"echo"},"tools":[{"type":"function","description":"Used for testing of llms, will echo the param given to it","name":"echo","parameters":{"type":"object","properties":{"string":{"type":"string","description":"string to echo"}},"required":["string"]},"strict":true}],"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

      event: response.output_item.added
      data: {"type":"response.output_item.added","sequence_number":2,"output_index":0,"item":{"id":"fc_684910c8b68881a3b43610e1d57ef00702d35c1819a50f63","type":"function_call","status":"in_progress","arguments":"","call_id":"call_TQyfNmFnKblzXl5rlcGeIsg5","name":"echo"}}

      event: response.function_call_arguments.delta
      data: {"type":"response.function_call_arguments.delta","sequence_number":3,"item_id":"fc_684910c8b68881a3b43610e1d57ef00702d35c1819a50f63","output_index":0,"delta":"{\\""}

      event: response.function_call_arguments.delta
      data: {"type":"response.function_call_arguments.delta","sequence_number":4,"item_id":"fc_684910c8b68881a3b43610e1d57ef00702d35c1819a50f63","output_index":0,"delta":"string"}

      event: response.function_call_arguments.delta
      data: {"type":"response.function_call_arguments.delta","sequence_number":5,"item_id":"fc_684910c8b68881a3b43610e1d57ef00702d35c1819a50f63","output_index":0,"delta":"\\":\\""}

      event: response.function_call_arguments.delta
      data: {"type":"response.function_call_arguments.delta","sequence_number":6,"item_id":"fc_684910c8b68881a3b43610e1d57ef00702d35c1819a50f63","output_index":0,"delta":"hello"}

      event: response.function_call_arguments.delta
      data: {"type":"response.function_call_arguments.delta","sequence_number":7,"item_id":"fc_684910c8b68881a3b43610e1d57ef00702d35c1819a50f63","output_index":0,"delta":"\\"}"}

      event: response.function_call_arguments.done
      data: {"type":"response.function_call_arguments.done","sequence_number":8,"item_id":"fc_684910c8b68881a3b43610e1d57ef00702d35c1819a50f63","output_index":0,"arguments":"{\\"string\\":\\"hello\\"}"}

      event: response.output_item.done
      data: {"type":"response.output_item.done","sequence_number":9,"output_index":0,"item":{"id":"fc_684910c8b68881a3b43610e1d57ef00702d35c1819a50f63","type":"function_call","status":"completed","arguments":"{\\"string\\":\\"hello\\"}","call_id":"call_TQyfNmFnKblzXl5rlcGeIsg5","name":"echo"}}

      event: response.completed
      data: {"type":"response.completed","sequence_number":10,"response":{"id":"resp_684910c81eec81a3a9222aa336d9fcf202d35c1819a50f63","object":"response","created_at":1749618888,"status":"completed","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"model":"gpt-4.1-nano-2025-04-14","output":[{"id":"fc_684910c8b68881a3b43610e1d57ef00702d35c1819a50f63","type":"function_call","status":"completed","arguments":"{\\"string\\":\\"hello\\"}","call_id":"call_TQyfNmFnKblzXl5rlcGeIsg5","name":"echo"}],"parallel_tool_calls":true,"previous_response_id":null,"reasoning":{"effort":null,"summary":null},"service_tier":"default","store":true,"temperature":1.0,"text":{"format":{"type":"text"}},"tool_choice":{"type":"function","name":"echo"},"tools":[{"type":"function","description":"Used for testing of llms, will echo the param given to it","name":"echo","parameters":{"type":"object","properties":{"string":{"type":"string","description":"string to echo"}},"required":["string"]},"strict":true}],"top_p":1.0,"truncation":"disabled","usage":{"input_tokens":71,"input_tokens_details":{"cached_tokens":0},"output_tokens":6,"output_tokens_details":{"reasoning_tokens":0},"total_tokens":77},"user":null,"metadata":{}}}

    TEXT

    partials = []

    stub_request(:post, "https://api.openai.com/v1/responses").to_return(
      status: 200,
      body: response_payload,
    )

    model
      .to_llm
      .generate(
        prompt_with_tools,
        user: Discourse.system_user,
        partial_tool_calls: true,
      ) { |partial| partials << partial.dup }

    # the partial tools are deduped
    expect(partials.length).to eq(1)

    expect(partials.first).to be_a(DiscourseAi::Completions::ToolCall)
    expect(partials.first.name).to eq("echo")
    expect(partials.first.parameters).to eq({ string: "hello" })
    expect(partials.first.id).to eq("call_TQyfNmFnKblzXl5rlcGeIsg5")
  end

  it "can handle non streaming tool calls" do
    response_object = {
      id: "resp_68491ed72974819f94652a73fb58109c08901d75ebf6c66e",
      object: "response",
      created_at: 1_749_622_487,
      status: "completed",
      background: false,
      error: nil,
      incomplete_details: nil,
      instructions: nil,
      max_output_tokens: nil,
      model: "gpt-4.1-nano-2025-04-14",
      output: [
        {
          id: "fc_68491ed75e0c819f87462ff642c58d2e08901d75ebf6c66e",
          type: "function_call",
          status: "completed",
          arguments: "{\"string\":\"sam\"}",
          call_id: "call_UdxBpinIVc5nRZ0VnWJIgneA",
          name: "echo",
        },
      ],
      parallel_tool_calls: true,
      previous_response_id: nil,
      reasoning: {
        effort: nil,
        summary: nil,
      },
      service_tier: "default",
      store: true,
      temperature: 1.0,
      text: {
        format: {
          type: "text",
        },
      },
      tool_choice: {
        type: "function",
        name: "echo",
      },
      tools: [
        {
          type: "function",
          description: "Used for testing of llms, will echo the param given to it",
          name: "echo",
          parameters: {
            type: "object",
            properties: {
              string: {
                type: "string",
                description: "string to echo",
              },
            },
            required: ["string"],
          },
          strict: true,
        },
      ],
      top_p: 1.0,
      truncation: "disabled",
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
      user: nil,
      metadata: {
      },
    }

    stub_request(:post, "https://api.openai.com/v1/responses").to_return(
      status: 200,
      body: response_object.to_json,
    )

    result = model.to_llm.generate(prompt_with_tools, user: Discourse.system_user)

    expect(result).to be_a(DiscourseAi::Completions::ToolCall)
    expect(result.name).to eq("echo")
    expect(result.parameters).to eq({ string: "sam" })
    expect(result.id).to eq("call_UdxBpinIVc5nRZ0VnWJIgneA")
  end
end
