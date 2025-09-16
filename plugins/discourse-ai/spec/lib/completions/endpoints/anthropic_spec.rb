# frozen_string_literal: true
require_relative "endpoint_compliance"

RSpec.describe DiscourseAi::Completions::Endpoints::Anthropic do
  let(:url) { "https://api.anthropic.com/v1/messages" }
  fab!(:model) { Fabricate(:anthropic_model, name: "claude-3-opus", vision_enabled: true) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(model) }
  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:upload100x100) do
    UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
  end

  let(:prompt) do
    DiscourseAi::Completions::Prompt.new(
      "You are hello bot",
      messages: [type: :user, id: "user1", content: "hello"],
    )
  end

  let(:echo_tool) do
    {
      name: "echo",
      description: "echo something",
      parameters: [{ name: "text", type: "string", description: "text to echo", required: true }],
    }
  end

  let(:google_tool) do
    {
      name: "google",
      description: "google something",
      parameters: [
        { name: "query", type: "string", description: "text to google", required: true },
      ],
    }
  end

  let(:prompt_with_echo_tool) do
    prompt_with_tools = prompt
    prompt.tools = [echo_tool]
    prompt_with_tools
  end

  let(:prompt_with_google_tool) do
    prompt_with_tools = prompt
    prompt.tools = [echo_tool]
    prompt_with_tools
  end

  before { enable_current_plugin }

  it "does not eat spaces with tool calls" do
    body = <<~STRING
    event: message_start
    data: {"type":"message_start","message":{"id":"msg_01Ju4j2MiGQb9KV9EEQ522Y3","type":"message","role":"assistant","model":"claude-3-haiku-20240307","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":1293,"output_tokens":1}}   }

    event: content_block_start
    data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_01DjrShFRRHp9SnHYRFRc53F","name":"search","input":{}}      }

    event: ping
    data: {"type": "ping"}

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":""}            }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"searc"}              }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"h_qu"}        }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"er"} }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"y\\": \\"s"}      }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"<a>m"}          }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":" "}          }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"sam\\""}          }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":", \\"cate"}         }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"gory"}   }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"\\": \\"gene"}               }

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"ral\\"}"}           }

    event: content_block_stop
    data: {"type":"content_block_stop","index":0     }

    event: message_delta
    data: {"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":70}       }

    event: message_stop
    data: {"type":"message_stop"}
    STRING

    result = []
    body = body.scan(/.*\n/)
    EndpointMock.with_chunk_array_support do
      stub_request(:post, url).to_return(status: 200, body: body)

      llm.generate(
        prompt_with_google_tool,
        user: Discourse.system_user,
        partial_tool_calls: true,
      ) { |partial| result << partial.dup }
    end

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "toolu_01DjrShFRRHp9SnHYRFRc53F",
        parameters: {
          search_query: "s<a>m sam",
          category: "general",
        },
      )

    expect(result.last).to eq(tool_call)

    search_queries = result.filter(&:partial).map { |r| r.parameters[:search_query] }
    categories = result.filter(&:partial).map { |r| r.parameters[:category] }

    expect(categories).to eq([nil, nil, nil, nil, "gene", "general"])
    expect(search_queries).to eq(["s", "s<a>m", "s<a>m ", "s<a>m sam", "s<a>m sam", "s<a>m sam"])
  end

  it "can stream a response" do
    body = (<<~STRING).strip
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_1nZdL29xx5MUA1yADyHTEsnR8uuvGzszyY", "type": "message", "role": "assistant", "content": [], "model": "claude-3-opus-20240229", "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 25, "output_tokens": 1}}}

      event: content_block_start
      data: {"type": "content_block_start", "index":0, "content_block": {"type": "text", "text": ""}}

      event: ping
      data: {"type": "ping"}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "!"}}

      event: content_block_stop
      data: {"type": "content_block_stop", "index": 0}

      event: message_delta
      data: {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence":null, "usage":{"output_tokens": 15}}}

      event: message_stop
      data: {"type": "message_stop"}
    STRING

    parsed_body = nil

    stub_request(:post, url).with(
      body:
        proc do |req_body|
          parsed_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
      headers: {
        "Content-Type" => "application/json",
        "X-Api-Key" => "123",
        "Anthropic-Version" => "2023-06-01",
      },
    ).to_return(status: 200, body: body)

    result = +""
    llm.generate(prompt, user: Discourse.system_user, feature_name: "testing") do |partial, cancel|
      result << partial
    end

    expect(result).to eq("Hello!")

    expected_body = {
      model: "claude-3-opus-20240229",
      max_tokens: 4096,
      messages: [{ role: "user", content: "user1: hello" }],
      system: "You are hello bot",
      stream: true,
    }
    expect(parsed_body).to eq(expected_body)

    log = AiApiAuditLog.order(:id).last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.feature_name).to eq("testing")
    expect(log.response_tokens).to eq(15)
    expect(log.request_tokens).to eq(25)
    expect(log.raw_request_payload).to eq(expected_body.to_json)
    expect(log.raw_response_payload.strip).to eq(body.strip)
  end

  it "supports non streaming tool calls" do
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

    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You a calculator",
        messages: [{ type: :user, id: "user1", content: "calculate 2758975 + 21.11" }],
        tools: [tool],
      )

    body = {
      id: "msg_01RdJkxCbsEj9VFyFYAkfy2S",
      type: "message",
      role: "assistant",
      model: "claude-3-haiku-20240307",
      content: [
        { type: "text", text: "Here is the calculation:" },
        {
          type: "tool_use",
          id: "toolu_012kBdhG4eHaV68W56p4N94h",
          name: "calculate",
          input: {
            expression: "2758975 + 21.11",
          },
        },
      ],
      stop_reason: "tool_use",
      stop_sequence: nil,
      usage: {
        input_tokens: 345,
        output_tokens: 65,
      },
    }.to_json

    stub_request(:post, url).to_return(body: body)

    result = llm.generate(prompt, user: Discourse.system_user)

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "calculate",
        id: "toolu_012kBdhG4eHaV68W56p4N94h",
        parameters: {
          expression: "2758975 + 21.11",
        },
      )

    expect(result).to eq(["Here is the calculation:", tool_call])

    log = AiApiAuditLog.order(:id).last
    expect(log.request_tokens).to eq(345)
    expect(log.response_tokens).to eq(65)
  end

  it "can send images via a completion prompt" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are image bot",
        messages: [type: :user, id: "user1", content: ["hello", { upload_id: upload100x100.id }]],
      )

    encoded = prompt.encoded_uploads(prompt.messages.last)

    request_body = {
      model: "claude-3-opus-20240229",
      max_tokens: 4096,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: "user1: hello" },
            {
              type: "image",
              source: {
                type: "base64",
                media_type: "image/jpeg",
                data: encoded[0][:base64],
              },
            },
          ],
        },
      ],
      system: "You are image bot",
    }

    response_body = <<~STRING
      {
        "content": [
          {
            "text": "What a cool image",
            "type": "text"
          }
        ],
        "id": "msg_013Zva2CMHLNnXjNJJKqJ2EF",
        "model": "claude-3-opus-20240229",
        "role": "assistant",
        "stop_reason": "end_turn",
        "stop_sequence": null,
        "type": "message",
        "usage": {
          "input_tokens": 10,
          "output_tokens": 25
        }
      }
    STRING

    requested_body = nil
    stub_request(:post, url).with(
      body:
        proc do |req_body|
          requested_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
    ).to_return(status: 200, body: response_body)

    result = llm.generate(prompt, user: Discourse.system_user)

    expect(result).to eq("What a cool image")
    expect(requested_body).to eq(request_body)
  end

  it "can support reasoning" do
    body = <<~STRING
      {
        "content": [
          {
            "text": "Hello!",
            "type": "text"
          }
        ],
        "id": "msg_013Zva2CMHLNnXjNJJKqJ2EF",
        "model": "claude-3-opus-20240229",
        "role": "assistant",
        "stop_reason": "end_turn",
        "stop_sequence": null,
        "type": "message",
        "usage": {
          "input_tokens": 10,
          "output_tokens": 25
        }
      }
    STRING

    parsed_body = nil
    stub_request(:post, url).with(
      body:
        proc do |req_body|
          parsed_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
      headers: {
        "Content-Type" => "application/json",
        "X-Api-Key" => "123",
        "Anthropic-Version" => "2023-06-01",
      },
    ).to_return(status: 200, body: body)

    model.provider_params["enable_reasoning"] = true
    model.provider_params["reasoning_tokens"] = 10_000
    model.save!

    proxy = DiscourseAi::Completions::Llm.proxy(model)
    result = proxy.generate(prompt, user: Discourse.system_user)
    expect(result).to eq("Hello!")

    expected_body = {
      model: "claude-3-opus-20240229",
      max_tokens: 40_000,
      thinking: {
        type: "enabled",
        budget_tokens: 10_000,
      },
      messages: [{ role: "user", content: "user1: hello" }],
      system: "You are hello bot",
    }
    expect(parsed_body).to eq(expected_body)

    log = AiApiAuditLog.order(:id).last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.request_tokens).to eq(10)
    expect(log.response_tokens).to eq(25)
  end

  it "can operate in regular mode" do
    body = <<~STRING
      {
        "content": [
          {
            "text": "Hello!",
            "type": "text"
          }
        ],
        "id": "msg_013Zva2CMHLNnXjNJJKqJ2EF",
        "model": "claude-3-opus-20240229",
        "role": "assistant",
        "stop_reason": "end_turn",
        "stop_sequence": null,
        "type": "message",
        "usage": {
          "input_tokens": 10,
          "output_tokens": 25
        }
      }
    STRING

    parsed_body = nil
    stub_request(:post, url).with(
      body:
        proc do |req_body|
          parsed_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
      headers: {
        "Content-Type" => "application/json",
        "X-Api-Key" => "123",
        "Anthropic-Version" => "2023-06-01",
      },
    ).to_return(status: 200, body: body)

    proxy = DiscourseAi::Completions::Llm.proxy(model)
    result = proxy.generate(prompt, user: Discourse.system_user)
    expect(result).to eq("Hello!")

    expected_body = {
      model: "claude-3-opus-20240229",
      max_tokens: 4096,
      messages: [{ role: "user", content: "user1: hello" }],
      system: "You are hello bot",
    }
    expect(parsed_body).to eq(expected_body)

    log = AiApiAuditLog.order(:id).last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.request_tokens).to eq(10)
    expect(log.response_tokens).to eq(25)
  end

  it "can send through thinking tokens via a completion prompt" do
    body = {
      id: "msg_1nZdL29xx5MUA1yADyHTEsnR8uuvGzszyY",
      type: "message",
      role: "assistant",
      content: [{ type: "text", text: "world" }],
      model: "claude-3-7-sonnet-20250219",
      stop_reason: "end_turn",
      usage: {
        input_tokens: 25,
        output_tokens: 40,
      },
    }.to_json

    parsed_body = nil
    stub_request(:post, url).with(
      body: ->(req_body) { parsed_body = JSON.parse(req_body) },
      headers: {
        "Content-Type" => "application/json",
        "X-Api-Key" => "123",
        "Anthropic-Version" => "2023-06-01",
      },
    ).to_return(status: 200, body: body)

    prompt = DiscourseAi::Completions::Prompt.new("system prompt")
    prompt.push(type: :user, content: "hello")
    prompt.push(
      type: :model,
      id: "user1",
      content: "hello",
      thinking: "I am thinking",
      thinking_signature: "signature",
      redacted_thinking_signature: "redacted_signature",
    )

    result = llm.generate(prompt, user: Discourse.system_user)
    expect(result).to eq("world")

    expected_body = {
      "model" => "claude-3-opus-20240229",
      "max_tokens" => 4096,
      "messages" => [
        { "role" => "user", "content" => "hello" },
        {
          "role" => "assistant",
          "content" => [
            { "type" => "thinking", "thinking" => "I am thinking", "signature" => "signature" },
            { "type" => "redacted_thinking", "data" => "redacted_signature" },
            { "type" => "text", "text" => "hello" },
          ],
        },
      ],
      "system" => "system prompt",
    }

    expect(parsed_body).to eq(expected_body)
  end

  it "can handle a response with thinking blocks in non-streaming mode" do
    body = {
      id: "msg_1nZdL29xx5MUA1yADyHTEsnR8uuvGzszyY",
      type: "message",
      role: "assistant",
      content: [
        {
          type: "thinking",
          thinking: "This is my thinking process about prime numbers...",
          signature: "abc123signature",
        },
        { type: "redacted_thinking", data: "abd456signature" },
        { type: "text", text: "Yes, there are infinitely many prime numbers where n mod 4 = 3." },
      ],
      model: "claude-3-7-sonnet-20250219",
      stop_reason: "end_turn",
      usage: {
        input_tokens: 25,
        output_tokens: 40,
      },
    }.to_json

    stub_request(:post, url).with(
      headers: {
        "Content-Type" => "application/json",
        "X-Api-Key" => "123",
        "Anthropic-Version" => "2023-06-01",
      },
    ).to_return(status: 200, body: body)

    result =
      llm.generate(
        "hello",
        user: Discourse.system_user,
        feature_name: "testing",
        output_thinking: true,
      )

    # Result should be an array with both thinking and text content
    expect(result).to be_an(Array)
    expect(result.length).to eq(3)

    # First item should be a Thinking object
    expect(result[0]).to be_a(DiscourseAi::Completions::Thinking)
    expect(result[0].message).to eq("This is my thinking process about prime numbers...")
    expect(result[0].signature).to eq("abc123signature")

    expect(result[1]).to be_a(DiscourseAi::Completions::Thinking)
    expect(result[1].signature).to eq("abd456signature")
    expect(result[1].redacted).to eq(true)

    # Second item should be the text response
    expect(result[2]).to eq("Yes, there are infinitely many prime numbers where n mod 4 = 3.")

    # Verify audit log
    log = AiApiAuditLog.order(:id).last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.feature_name).to eq("testing")
    expect(log.response_tokens).to eq(40)
  end

  it "can stream a response with thinking blocks" do
    body = (<<~STRING).strip
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_01...", "type": "message", "role": "assistant", "content": [], "model": "claude-3-opus-20240229", "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 25}}}

      event: content_block_start
      data: {"type": "content_block_start", "index": 0, "content_block": {"type": "thinking", "thinking": ""}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "thinking_delta", "thinking": "Let me solve this step by step:\\n\\n1. First break down 27 * 453"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "thinking_delta", "thinking": "\\n2. 453 = 400 + 50 + 3"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "signature_delta", "signature": "EqQBCgIYAhIM1gbcDa9GJwZA2b3hGgxBdjrkzLoky3dl1pkiMOYds..."}}

      event: content_block_stop
      data: {"type": "content_block_stop", "index": 0}

      event: content_block_start
      data: {"type":"content_block_start","index":0,"content_block":{"type":"redacted_thinking","data":"AAA=="} }

      event: ping
      data: {"type": "ping"}

      event: content_block_stop
      data: {"type":"content_block_stop","index":0 }

      event: content_block_start
      data: {"type": "content_block_start", "index": 1, "content_block": {"type": "text", "text": ""}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 1, "delta": {"type": "text_delta", "text": "27 * 453 = 12,231"}}

      event: content_block_stop
      data: {"type": "content_block_stop", "index": 1}

      event: message_delta
      data: {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence": null, "usage": {"output_tokens": 30}}}

      event: message_stop
      data: {"type": "message_stop"}
    STRING

    parsed_body = nil

    stub_request(:post, url).with(
      headers: {
        "Content-Type" => "application/json",
        "X-Api-Key" => "123",
        "Anthropic-Version" => "2023-06-01",
      },
    ).to_return(status: 200, body: body)

    thinking_chunks = []
    text_chunks = []

    llm.generate(
      "hello there",
      user: Discourse.system_user,
      feature_name: "testing",
      output_thinking: true,
    ) do |partial, cancel|
      if partial.is_a?(DiscourseAi::Completions::Thinking)
        thinking_chunks << partial
      else
        text_chunks << partial
      end
    end

    expected_thinking = [
      DiscourseAi::Completions::Thinking.new(message: "", signature: "", partial: true),
      DiscourseAi::Completions::Thinking.new(
        message: "Let me solve this step by step:\n\n1. First break down 27 * 453",
        partial: true,
      ),
      DiscourseAi::Completions::Thinking.new(message: "\n2. 453 = 400 + 50 + 3", partial: true),
      DiscourseAi::Completions::Thinking.new(
        message:
          "Let me solve this step by step:\n\n1. First break down 27 * 453\n2. 453 = 400 + 50 + 3",
        signature: "EqQBCgIYAhIM1gbcDa9GJwZA2b3hGgxBdjrkzLoky3dl1pkiMOYds...",
        partial: false,
      ),
      DiscourseAi::Completions::Thinking.new(message: nil, signature: "AAA==", redacted: true),
    ]

    expect(thinking_chunks).to eq(expected_thinking)
    expect(text_chunks).to eq(["27 * 453 = 12,231"])

    log = AiApiAuditLog.order(:id).last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.feature_name).to eq("testing")
    expect(log.response_tokens).to eq(30)
  end

  describe "max output tokens" do
    it "it respects max output tokens supplied to model unconditionally, even with thinking" do
      model.update!(
        provider_params: {
          enable_reasoning: true,
          reasoning_tokens: 1000,
        },
        max_output_tokens: 2000,
      )

      parsed_body = nil
      stub_request(:post, url).with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
        headers: {
          "Content-Type" => "application/json",
          "X-Api-Key" => "123",
          "Anthropic-Version" => "2023-06-01",
        },
      ).to_return(
        status: 200,
        body: {
          id: "msg_123",
          type: "message",
          role: "assistant",
          content: [{ type: "text", text: "test response" }],
          model: "claude-3-opus-20240229",
          usage: {
            input_tokens: 10,
            output_tokens: 5,
          },
        }.to_json,
      )

      llm.generate(prompt, user: Discourse.system_user, max_tokens: 2500)
      expect(parsed_body[:max_tokens]).to eq(2000)

      llm.generate(prompt, user: Discourse.system_user)
      expect(parsed_body[:max_tokens]).to eq(2000)
    end
  end

  describe "parameter disabling" do
    it "excludes disabled parameters from the request" do
      model.update!(provider_params: { disable_top_p: true, disable_temperature: true })

      parsed_body = nil
      stub_request(:post, url).with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
        headers: {
          "Content-Type" => "application/json",
          "X-Api-Key" => "123",
          "Anthropic-Version" => "2023-06-01",
        },
      ).to_return(
        status: 200,
        body: {
          id: "msg_123",
          type: "message",
          role: "assistant",
          content: [{ type: "text", text: "test response" }],
          model: "claude-3-opus-20240229",
          usage: {
            input_tokens: 10,
            output_tokens: 5,
          },
        }.to_json,
      )

      # Request with parameters that should be ignored
      llm.generate(
        prompt,
        user: Discourse.system_user,
        top_p: 0.9,
        temperature: 0.8,
        max_tokens: 500,
      )

      # Verify disabled parameters aren't included
      expect(parsed_body).not_to have_key(:top_p)
      expect(parsed_body).not_to have_key(:temperature)

      # Verify other parameters still work
      expect(parsed_body).to have_key(:max_tokens)
      expect(parsed_body[:max_tokens]).to eq(500)
    end
  end

  describe "disabled tool use" do
    it "can properly disable tool use with :none" do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [type: :user, id: "user1", content: "don't use any tools please"],
          tools: [echo_tool],
          tool_choice: :none,
        )

      response_body = {
        id: "msg_01RdJkxCbsEj9VFyFYAkfy2S",
        type: "message",
        role: "assistant",
        model: "claude-3-haiku-20240307",
        content: [
          { type: "text", text: "I won't use any tools. Here's a direct response instead." },
        ],
        stop_reason: "end_turn",
        stop_sequence: nil,
        usage: {
          input_tokens: 345,
          output_tokens: 65,
        },
      }.to_json

      parsed_body = nil
      stub_request(:post, url).with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
      ).to_return(status: 200, body: response_body)

      result = llm.generate(prompt, user: Discourse.system_user)

      # Verify that tool_choice is set to { type: "none" }
      expect(parsed_body[:tool_choice]).to eq({ type: "none" })

      # Verify that an assistant message with no_more_tool_calls_text was added
      messages = parsed_body[:messages]
      expect(messages.length).to eq(2) # user message + added assistant message

      last_message = messages.last
      expect(last_message[:role]).to eq("assistant")

      expect(last_message[:content]).to eq(
        DiscourseAi::Completions::Dialects::Dialect.no_more_tool_calls_text,
      )

      expect(result).to eq("I won't use any tools. Here's a direct response instead.")
    end
  end

  describe "forced tool use" do
    it "can properly force tool use" do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [type: :user, id: "user1", content: "echo hello"],
          tools: [echo_tool],
          tool_choice: "echo",
        )

      response_body = {
        id: "msg_01RdJkxCbsEj9VFyFYAkfy2S",
        type: "message",
        role: "assistant",
        model: "claude-3-haiku-20240307",
        content: [
          {
            type: "tool_use",
            id: "toolu_bdrk_014CMjxtGmKUtGoEFPgc7PF7",
            name: "echo",
            input: {
              text: "hello",
            },
          },
        ],
        stop_reason: "end_turn",
        stop_sequence: nil,
        usage: {
          input_tokens: 345,
          output_tokens: 65,
        },
      }.to_json

      parsed_body = nil
      stub_request(:post, url).with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
      ).to_return(status: 200, body: response_body)

      llm.generate(prompt, user: Discourse.system_user)

      # Verify that tool_choice: "echo" is present
      expect(parsed_body.dig(:tool_choice, :name)).to eq("echo")
    end
  end

  describe "structured output via prefilling" do
    it "forces the response to be a JSON and using the given JSON schema" do
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
            },
            required: ["key"],
            additionalProperties: false,
          },
          strict: true,
        },
      }

      body = (<<~STRING).strip
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_1nZdL29xx5MUA1yADyHTEsnR8uuvGzszyY", "type": "message", "role": "assistant", "content": [], "model": "claude-3-opus-20240229", "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 25, "output_tokens": 1}}}

      event: content_block_start
      data: {"type": "content_block_start", "index":0, "content_block": {"type": "text", "text": ""}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "\\""}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "key"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "\\":\\""}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello!\\n"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": " there\\nis a text"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": " and\\n\\nmore text"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "\\n \\n and\\n\\n more much more"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": " text"}}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "\\"}"}}

      event: content_block_stop
      data: {"type": "content_block_stop", "index": 0}

      event: message_delta
      data: {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence":null, "usage":{"output_tokens": 15}}}

      event: message_stop
      data: {"type": "message_stop"}
    STRING

      parsed_body = nil

      stub_request(:post, url).with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
        headers: {
          "Content-Type" => "application/json",
          "X-Api-Key" => "123",
          "Anthropic-Version" => "2023-06-01",
        },
      ).to_return(status: 200, body: body)

      structured_output = nil
      llm.generate(
        prompt,
        user: Discourse.system_user,
        feature_name: "testing",
        response_format: schema,
      ) { |partial, cancel| structured_output = partial }

      expect(structured_output.read_buffered_property(:key)).to eq(
        "Hello!\n there\nis a text and\n\nmore text\n \n and\n\n more much more text",
      )

      expected_body = {
        model: "claude-3-opus-20240229",
        max_tokens: 4096,
        messages: [{ role: "user", content: "user1: hello" }, { role: "assistant", content: "{" }],
        system: "You are hello bot",
        stream: true,
      }
      expect(parsed_body).to eq(expected_body)
    end
  end
end
