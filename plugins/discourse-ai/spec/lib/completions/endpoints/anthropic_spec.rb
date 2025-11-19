# frozen_string_literal: true
require_relative "endpoint_compliance"

RSpec.describe DiscourseAi::Completions::Endpoints::Anthropic do
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

  def with_scripted_responses(responses, llm_model: model, &block)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      responses,
      llm: llm_model,
      transport: :scripted_http,
      &block
    )
  end

  def raw_stream_chunks(stream_payload)
    stream_payload.lines.map { |line| line.end_with?("\n") ? line : "#{line}\n" }
  end

  it "does not eat spaces with tool calls" do
    response = {
      tool_calls: [
        {
          id: "toolu_01DjrShFRRHp9SnHYRFRc53F",
          name: "search",
          arguments: {
            search_query: "s<a>m  sam",
            category: "general",
          },
        },
      ],
      usage: {
        input_tokens: 1293,
        output_tokens: 70,
      },
    }

    result = []
    with_scripted_responses([response]) do
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
          search_query: "s<a>m  sam",
          category: "general",
        },
      )

    expect(result.last).to eq(tool_call)

    search_queries = result.filter(&:partial).map { |r| r.parameters[:search_query] }
    categories = result.filter(&:partial).map { |r| r.parameters[:category] }

    expect(categories).to eq([nil, nil, nil, nil, nil, nil, "gen", "gener", "general", "general"])
    expect(search_queries).to eq(
      [
        "s",
        "s<a>",
        "s<a>m ",
        "s<a>m  ",
        "s<a>m  sam",
        "s<a>m  sam",
        "s<a>m  sam",
        "s<a>m  sam",
        "s<a>m  sam",
        "s<a>m  sam",
      ],
    )
  end

  it "can stream a response" do
    parsed_body = nil
    result = +""
    with_scripted_responses(["Hello!"]) do |scripted_http|
      llm.generate(
        prompt,
        user: Discourse.system_user,
        feature_name: "testing",
      ) { |partial, cancel| result << partial }
      parsed_body = scripted_http.last_request.deep_symbolize_keys
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
    expect(log.response_tokens).to eq(2)
    expect(log.request_tokens).to eq(8)
    expect(log.raw_request_payload).to eq(expected_body.to_json)
    expect(log.raw_response_payload.strip).to be_present
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

    response = {
      content: "Here is the calculation:",
      tool_calls: [
        {
          id: "toolu_012kBdhG4eHaV68W56p4N94h",
          name: "calculate",
          arguments: {
            expression: "2758975 + 21.11",
          },
        },
      ],
      usage: {
        input_tokens: 345,
        output_tokens: 65,
      },
    }

    result = nil
    with_scripted_responses([response]) do
      result = llm.generate(prompt, user: Discourse.system_user)
    end

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

    requested_body = nil

    result = nil
    with_scripted_responses(["What a cool image"]) do |scripted_http|
      result = llm.generate(prompt, user: Discourse.system_user)
      requested_body = scripted_http.last_request.deep_symbolize_keys
    end

    expect(result).to eq("What a cool image")
    expect(requested_body).to eq(request_body)
  end

  it "can support reasoning" do
    model.provider_params["enable_reasoning"] = true
    model.provider_params["reasoning_tokens"] = 10_000
    model.save!

    parsed_body = nil
    response = { content: "Hello!", usage: { input_tokens: 10, output_tokens: 25 } }

    result = nil
    with_scripted_responses([response], llm_model: model) do |scripted_http|
      result = llm.generate(prompt, user: Discourse.system_user)
      parsed_body = scripted_http.last_request.deep_symbolize_keys
    end
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
    parsed_body = nil
    result = nil
    response = { content: "Hello!", usage: { input_tokens: 10, output_tokens: 25 } }

    with_scripted_responses([response]) do |scripted_http|
      result = llm.generate(prompt, user: Discourse.system_user)
      parsed_body = scripted_http.last_request.deep_symbolize_keys
    end
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
    prompt = DiscourseAi::Completions::Prompt.new("system prompt")
    prompt.push(type: :user, content: "hello")
    prompt.push(
      type: :model,
      id: "user1",
      content: "hello",
      thinking: "I am thinking",
      thinking_provider_info: {
        anthropic: {
          signature: "signature",
          redacted_signature: "redacted_signature",
        },
      },
    )

    parsed_body = nil
    result = nil
    response = { content: "world", usage: { input_tokens: 25, output_tokens: 40 } }

    with_scripted_responses([response]) do |scripted_http|
      result = llm.generate(prompt, user: Discourse.system_user)
      parsed_body = scripted_http.last_request
    end
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
    response = {
      content_blocks: [
        {
          type: :thinking,
          thinking: "This is my thinking process about prime numbers...",
          signature: "abc123signature",
        },
        { type: :redacted_thinking, data: "abd456signature" },
        { type: :text, text: "Yes, there are infinitely many prime numbers where n mod 4 = 3." },
      ],
      usage: {
        input_tokens: 25,
        output_tokens: 40,
      },
    }

    result = nil
    with_scripted_responses([response]) do
      result =
        llm.generate(
          "hello",
          user: Discourse.system_user,
          feature_name: "testing",
          output_thinking: true,
        )
    end

    # Result should be an array with both thinking and text content
    expect(result).to be_an(Array)
    expect(result.length).to eq(3)

    # First item should be a Thinking object
    expect(result[0]).to be_a(DiscourseAi::Completions::Thinking)
    expect(result[0].message).to eq("This is my thinking process about prime numbers...")
    expect(result[0].provider_info[:anthropic][:signature]).to eq("abc123signature")

    expect(result[1]).to be_a(DiscourseAi::Completions::Thinking)
    expect(result[1].provider_info[:anthropic][:redacted_signature]).to eq("abd456signature")

    # Second item should be the text response
    expect(result[2]).to eq("Yes, there are infinitely many prime numbers where n mod 4 = 3.")

    # Verify audit log
    log = AiApiAuditLog.order(:id).last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Anthropic)
    expect(log.feature_name).to eq("testing")
    expect(log.response_tokens).to eq(40)
  end

  it "can stream a response with thinking blocks" do
    thinking_full =
      "Let me solve this step by step:\n\n1. First break down 27 * 453\n2. 453 = 400 + 50 + 3"
    response = {
      content_blocks: [
        {
          type: :thinking,
          thinking: thinking_full,
          thinking_chunks: [
            "Let me solve this step by step:\n\n1. First break down 27 * 453",
            "\n2. 453 = 400 + 50 + 3",
          ],
          signature: "EqQBCgIYAhIM1gbcDa9GJwZA2b3hGgxBdjrkzLoky3dl1pkiMOYds...",
        },
        { type: :redacted_thinking, data: "AAA==" },
        { type: :text, text: "27 * 453 = 12,231", text_chunks: ["27 * 453 = 12,231"] },
      ],
      usage: {
        input_tokens: 25,
        output_tokens: 30,
      },
    }

    thinking_chunks = []
    text_chunks = []

    with_scripted_responses([response]) do
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
    end

    expected_thinking = [
      DiscourseAi::Completions::Thinking.new(
        message: "",
        partial: true,
        provider_info: {
          anthropic: {
            signature: "",
            redacted: false,
          },
        },
      ),
      DiscourseAi::Completions::Thinking.new(
        message: "Let me solve this step by step:\n\n1. First break down 27 * 453",
        partial: true,
      ),
      DiscourseAi::Completions::Thinking.new(message: "\n2. 453 = 400 + 50 + 3", partial: true),
      DiscourseAi::Completions::Thinking.new(
        message:
          "Let me solve this step by step:\n\n1. First break down 27 * 453\n2. 453 = 400 + 50 + 3",
        partial: false,
        provider_info: {
          anthropic: {
            signature: "EqQBCgIYAhIM1gbcDa9GJwZA2b3hGgxBdjrkzLoky3dl1pkiMOYds...",
            redacted: false,
          },
        },
      ),
      DiscourseAi::Completions::Thinking.new(
        message: nil,
        partial: false,
        provider_info: {
          anthropic: {
            redacted_signature: "AAA==",
            redacted: true,
          },
        },
      ),
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

      with_scripted_responses(["test response", "test response"]) do |scripted_http|
        llm.generate(prompt, user: Discourse.system_user, max_tokens: 2500)
        expect(scripted_http.last_request["max_tokens"]).to eq(2000)

        llm.generate(prompt, user: Discourse.system_user)
        expect(scripted_http.last_request["max_tokens"]).to eq(2000)
      end
    end
  end

  describe "parameter disabling" do
    it "excludes disabled parameters from the request" do
      model.update!(provider_params: { disable_top_p: true, disable_temperature: true })

      with_scripted_responses(["test response"]) do |scripted_http|
        llm.generate(
          prompt,
          user: Discourse.system_user,
          top_p: 0.9,
          temperature: 0.8,
          max_tokens: 500,
        )

        parsed_body = scripted_http.last_request.deep_symbolize_keys

        # Verify disabled parameters aren't included
        expect(parsed_body).not_to have_key(:top_p)
        expect(parsed_body).not_to have_key(:temperature)

        # Verify other parameters still work
        expect(parsed_body).to have_key(:max_tokens)
        expect(parsed_body[:max_tokens]).to eq(500)
      end
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

      parsed_body = nil
      result = nil

      with_scripted_responses(
        ["I won't use any tools. Here's a direct response instead."],
      ) do |scripted_http|
        result = llm.generate(prompt, user: Discourse.system_user)
        parsed_body = scripted_http.last_request.deep_symbolize_keys
      end

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

      parsed_body = nil
      response = {
        tool_calls: [
          { id: "toolu_bdrk_014CMjxtGmKUtGoEFPgc7PF7", name: "echo", arguments: { text: "hello" } },
        ],
      }

      with_scripted_responses([response]) do |scripted_http|
        llm.generate(prompt, user: Discourse.system_user)
        parsed_body = scripted_http.last_request.deep_symbolize_keys
      end

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

      structured_output = nil
      parsed_body = nil

      with_scripted_responses([{ raw_stream: raw_stream_chunks(body) }]) do |scripted_http|
        llm.generate(
          prompt,
          user: Discourse.system_user,
          feature_name: "testing",
          response_format: schema,
        ) { |partial, cancel| structured_output = partial }

        parsed_body = scripted_http.last_request.deep_symbolize_keys
      end

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
