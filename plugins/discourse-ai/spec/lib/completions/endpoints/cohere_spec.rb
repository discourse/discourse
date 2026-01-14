# frozen_string_literal: true
require_relative "endpoint_compliance"

RSpec.describe DiscourseAi::Completions::Endpoints::Cohere do
  fab!(:cohere_model)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(cohere_model) }
  fab!(:user)

  let(:prompt) do
    DiscourseAi::Completions::Prompt.new(
      "You are hello bot",
      messages: [
        { type: :user, id: "user1", content: "hello" },
        { type: :model, content: "hi user" },
        { type: :user, id: "user1", content: "thanks" },
      ],
    )
  end

  let(:weather_tool) do
    {
      name: "weather",
      description: "lookup weather in a city",
      parameters: [{ name: "city", type: "string", description: "city name", required: true }],
    }
  end

  let(:prompt_with_tools) do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are weather bot",
        messages: [
          { type: :user, id: "user1", content: "what is the weather in sydney and melbourne?" },
        ],
      )

    prompt.tools = [weather_tool]
    prompt
  end

  let(:prompt_with_tool_results) do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are weather bot",
        messages: [
          { type: :user, id: "user1", content: "what is the weather in sydney and melbourne?" },
          {
            type: :tool_call,
            id: "tool_call_1",
            name: "weather",
            content: { arguments: [%w[city Sydney]] }.to_json,
          },
          { type: :tool, id: "tool_call_1", name: "weather", content: { weather: "22c" }.to_json },
        ],
      )

    prompt.tools = [weather_tool]
    prompt
  end

  before { enable_current_plugin }

  it "is able to trigger a tool" do
    body = (<<~TEXT).strip
      {"is_finished":false,"event_type":"stream-start","generation_id":"1648206e-1fe4-4bb6-90cf-360dd55f575b"}
{"is_finished":false,"event_type":"tool-calls-generation","text":"I will search for 'who is sam saffron' and relay the information to the user.","tool_calls":[{"name":"google","parameters":{"query":"who is sam saffron"}}]}
{"is_finished":true,"event_type":"stream-end","response":{"response_id":"71d8c9e1-1138-4d70-80d1-10ddec41c989","text":"I will search for 'who is sam saffron' and relay the information to the user.","generation_id":"1648206e-1fe4-4bb6-90cf-360dd55f575b","chat_history":[{"role":"USER","message":"sam: who is sam saffron?"},{"role":"CHATBOT","message":"I will search for 'who is sam saffron' and relay the information to the user.","tool_calls":[{"name":"google","parameters":{"query":"who is sam saffron"}}]}],"finish_reason":"COMPLETE","meta":{"api_version":{"version":"1"},"billed_units":{"input_tokens":460,"output_tokens":27},"tokens":{"input_tokens":1227,"output_tokens":27}},"tool_calls":[{"name":"google","parameters":{"query":"who is sam saffron"}}]},"finish_reason":"COMPLETE"}
    TEXT

    parsed_body = nil
    result = []

    sig = {
      name: "google",
      description: "Will search using Google",
      parameters: [
        { name: "query", description: "The search query", type: "string", required: true },
      ],
    }

    prompt.tools = [sig]

    EndpointMock.with_chunk_array_support do
      stub_request(:post, "https://api.cohere.ai/v1/chat").with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer ABC",
        },
      ).to_return(status: 200, body: body.split("|"))

      llm.generate(prompt, user: user) { |partial, cancel| result << partial }
    end

    text = "I will search for 'who is sam saffron' and relay the information to the user."
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "tool_0",
        name: "google",
        parameters: {
          query: "who is sam saffron",
        },
      )

    expect(result).to eq([text, tool_call])

    expected = {
      model: "command-r-plus",
      preamble: "You are hello bot",
      chat_history: [
        { role: "USER", message: "user1: hello" },
        { role: "CHATBOT", message: "hi user" },
      ],
      message: "user1: thanks",
      tools: [
        {
          name: "google",
          description: "Will search using Google",
          parameter_definitions: {
            query: {
              description: "The search query",
              type: "str",
              required: true,
            },
          },
        },
      ],
      force_single_step: false,
      stream: true,
    }

    expect(parsed_body).to eq(expected)
  end

  it "is able to run tools" do
    body = {
      response_id: "0a90275b-273d-4690-abce-8018edcec7d0",
      text: "Sydney is 22c",
      generation_id: "cc2742f7-622c-4e42-8fd4-d95b21012e52",
      chat_history: [],
      finish_reason: "COMPLETE",
      token_count: {
        prompt_tokens: 29,
        response_tokens: 11,
        total_tokens: 40,
        billed_tokens: 25,
      },
      meta: {
        api_version: {
          version: "1",
        },
        billed_units: {
          input_tokens: 17,
          output_tokens: 22,
        },
      },
    }.to_json

    parsed_body = nil
    stub_request(:post, "https://api.cohere.ai/v1/chat").with(
      body:
        proc do |req_body|
          parsed_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer ABC",
      },
    ).to_return(status: 200, body: body)

    result = llm.generate(prompt_with_tool_results, user: user)

    expect(parsed_body[:preamble]).to include("You are weather bot")

    expect(result).to eq("Sydney is 22c")
    audit = AiApiAuditLog.order("id desc").first

    # billing should be picked
    expect(audit.request_tokens).to eq(17)
    expect(audit.response_tokens).to eq(22)

    expect(audit.language_model).to eq("command-r-plus")
  end

  it "is able to perform streaming completions" do
    body = <<~TEXT
      {"is_finished":false,"event_type":"stream-start","generation_id":"eb889b0f-c27d-45ea-98cf-567bdb7fc8bf"}
      {"is_finished":false,"event_type":"text-generation","text":"You"}
      {"is_finished":false,"event_type":"text-generation","text":"'re"}
      {"is_finished":false,"event_type":"text-generation","text":" welcome"}
      {"is_finished":false,"event_type":"text-generation","text":"!"}
      {"is_finished":false,"event_type":"text-generation","text":" Is"}
      {"is_finished":false,"event_type":"text-generation","text":" there"}
      {"is_finished":false,"event_type":"text-generation","text":" anything"}|
      {"is_finished":false,"event_type":"text-generation","text":" else"}
      {"is_finished":false,"event_type":"text-generation","text":" I"}
      {"is_finished":false,"event_type":"text-generation","text":" can"}
      {"is_finished":false,"event_type":"text-generation","text":" help"}|
      {"is_finished":false,"event_type":"text-generation","text":" you"}
      {"is_finished":false,"event_type":"text-generation","text":" with"}
      {"is_finished":false,"event_type":"text-generation","text":"?"}|
      {"is_finished":true,"event_type":"stream-end","response":{"response_id":"d235db17-8555-493b-8d91-e601f76de3f9","text":"You're welcome! Is there anything else I can help you with?","generation_id":"eb889b0f-c27d-45ea-98cf-567bdb7fc8bf","chat_history":[{"role":"USER","message":"user1: hello"},{"role":"CHATBOT","message":"hi user"},{"role":"USER","message":"user1: thanks"},{"role":"CHATBOT","message":"You're welcome! Is there anything else I can help you with?"}],"token_count":{"prompt_tokens":29,"response_tokens":14,"total_tokens":43,"billed_tokens":28},"meta":{"api_version":{"version":"1"},"billed_units":{"input_tokens":14,"output_tokens":14}}},"finish_reason":"COMPLETE"}
    TEXT

    parsed_body = nil
    result = +""

    EndpointMock.with_chunk_array_support do
      stub_request(:post, "https://api.cohere.ai/v1/chat").with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer ABC",
        },
      ).to_return(status: 200, body: body.split("|"))

      result = llm.generate(prompt, user: user) { |partial, cancel| result << partial }
    end

    expect(parsed_body[:preamble]).to eq("You are hello bot")
    expect(parsed_body[:chat_history]).to eq(
      [{ role: "USER", message: "user1: hello" }, { role: "CHATBOT", message: "hi user" }],
    )
    expect(parsed_body[:message]).to eq("user1: thanks")

    expect(result).to eq("You're welcome! Is there anything else I can help you with?")
    audit = AiApiAuditLog.order("id desc").first

    # billing should be picked
    expect(audit.request_tokens).to eq(14)
    expect(audit.response_tokens).to eq(14)
  end

  it "is able to perform non streaming completions" do
    body = {
      response_id: "0a90275b-273d-4690-abce-8018edcec7d0",
      text: "You're welcome! How can I help you today?",
      generation_id: "cc2742f7-622c-4e42-8fd4-d95b21012e52",
      chat_history: [
        { role: "USER", message: "user1: hello" },
        { role: "CHATBOT", message: "hi user" },
        { role: "USER", message: "user1: thanks" },
        { role: "CHATBOT", message: "You're welcome! How can I help you today?" },
      ],
      finish_reason: "COMPLETE",
      token_count: {
        prompt_tokens: 29,
        response_tokens: 11,
        total_tokens: 40,
        billed_tokens: 25,
      },
      meta: {
        api_version: {
          version: "1",
        },
        billed_units: {
          input_tokens: 14,
          output_tokens: 11,
        },
      },
    }.to_json

    parsed_body = nil
    stub_request(:post, "https://api.cohere.ai/v1/chat").with(
      body:
        proc do |req_body|
          parsed_body = JSON.parse(req_body, symbolize_names: true)
          true
        end,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer ABC",
      },
    ).to_return(status: 200, body: body)

    result =
      llm.generate(
        prompt,
        user: user,
        temperature: 0.1,
        top_p: 0.5,
        max_tokens: 100,
        stop_sequences: ["stop"],
      )

    expect(parsed_body[:temperature]).to eq(0.1)
    expect(parsed_body[:p]).to eq(0.5)
    expect(parsed_body[:max_tokens]).to eq(100)
    expect(parsed_body[:stop_sequences]).to eq(["stop"])

    expect(parsed_body[:preamble]).to eq("You are hello bot")
    expect(parsed_body[:chat_history]).to eq(
      [{ role: "USER", message: "user1: hello" }, { role: "CHATBOT", message: "hi user" }],
    )
    expect(parsed_body[:message]).to eq("user1: thanks")

    expect(result).to eq("You're welcome! How can I help you today?")
    audit = AiApiAuditLog.order("id desc").first

    # billing should be picked
    expect(audit.request_tokens).to eq(14)
    expect(audit.response_tokens).to eq(11)
  end

  it "is able to return structured outputs" do
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

    body = <<~TEXT
      {"is_finished":false,"event_type":"stream-start","generation_id":"eb889b0f-c27d-45ea-98cf-567bdb7fc8bf"}
      {"is_finished":false,"event_type":"text-generation","text":"{\\""}
      {"is_finished":false,"event_type":"text-generation","text":"key"}
      {"is_finished":false,"event_type":"text-generation","text":"\\":\\""}
      {"is_finished":false,"event_type":"text-generation","text":"Hello!"}
      {"is_finished":false,"event_type":"text-generation","text":"\\n there"}
      {"is_finished":false,"event_type":"text-generation","text":"\\"}"}|
      {"is_finished":true,"event_type":"stream-end","response":{"response_id":"d235db17-8555-493b-8d91-e601f76de3f9","text":"{\\"key\\":\\"Hello! \\n there\\"}","generation_id":"eb889b0f-c27d-45ea-98cf-567bdb7fc8bf","chat_history":[{"role":"USER","message":"user1: hello"},{"role":"CHATBOT","message":"hi user"},{"role":"USER","message":"user1: thanks"},{"role":"CHATBOT","message":"You're welcome! Is there anything else I can help you with?"}],"token_count":{"prompt_tokens":29,"response_tokens":14,"total_tokens":43,"billed_tokens":28},"meta":{"api_version":{"version":"1"},"billed_units":{"input_tokens":14,"output_tokens":14}}},"finish_reason":"COMPLETE"}
    TEXT

    parsed_body = nil
    structured_output = nil

    EndpointMock.with_chunk_array_support do
      stub_request(:post, "https://api.cohere.ai/v1/chat").with(
        body:
          proc do |req_body|
            parsed_body = JSON.parse(req_body, symbolize_names: true)
            true
          end,
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer ABC",
        },
      ).to_return(status: 200, body: body.split("|"))

      result =
        llm.generate(prompt, response_format: schema, user: user) do |partial, cancel|
          structured_output = partial
        end
    end

    expect(parsed_body[:preamble]).to eq("You are hello bot")
    expect(parsed_body[:chat_history]).to eq(
      [{ role: "USER", message: "user1: hello" }, { role: "CHATBOT", message: "hi user" }],
    )
    expect(parsed_body[:message]).to eq("user1: thanks")

    expect(structured_output.read_buffered_property(:key)).to eq("Hello!\n there")
  end
end
