# frozen_string_literal: true

require_relative "endpoint_compliance"

# nova is all implemented in bedrock endpoint, split out here
RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrock do
  fab!(:user)
  fab!(:nova_model)

  subject(:endpoint) { described_class.new(nova_model) }

  before { enable_current_plugin }

  def with_scripted_responses(responses, llm_model: nova_model, &block)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      responses,
      llm: llm_model,
      transport: :scripted_http,
      &block
    )
  end

  it "should be able to make a simple request" do
    usage = {
      "inputTokens" => 14,
      "outputTokens" => 119,
      "totalTokens" => 133,
      "cacheReadInputTokenCount" => nil,
      "cacheWriteInputTokenCount" => nil,
    }

    with_scripted_responses([{ content: "it is 2.", usage: usage }]) do
      proxy = DiscourseAi::Completions::Llm.proxy(nova_model)
      response = proxy.generate("hello world", user: user)
      expect(response).to eq("it is 2.")
    end

    log = AiApiAuditLog.order(:id).last
    expect(log.request_tokens).to eq(14)
    expect(log.response_tokens).to eq(119)
  end

  it "should be able to make a streaming request" do
    usage = { "inputTokens" => 14, "outputTokens" => 18, "totalTokens" => 32 }

    with_scripted_responses([{ content: "Hello!", usage: usage }]) do
      proxy = DiscourseAi::Completions::Llm.proxy(nova_model)
      responses = []
      proxy.generate("Hello!", user: user) { |partial| responses << partial }

      expect(responses.join).to eq("Hello!")
      expect(responses.length).to be > 1
    end

    log = AiApiAuditLog.order(:id).last
    expect(log.request_tokens).to eq(14)
    expect(log.response_tokens).to eq(18)
  end

  it "should support native streaming tool calls" do
    #model.provider_params["disable_native_tools"] = true
    #model.save!

    proxy = DiscourseAi::Completions::Llm.proxy(nova_model)
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are a helpful assistant.",
        messages: [{ type: :user, content: "what is the time in EST" }],
      )

    tool = {
      name: "time",
      description: "Will look up the current time",
      parameters: [
        { name: "timezone", description: "The timezone", type: "string", required: true },
      ],
    }

    prompt.tools = [tool]

    response_payload = {
      tool_calls: [
        {
          id: "e1bd7033-7244-4408-b088-1d33cbcf0b67",
          name: "time",
          arguments: {
            timezone: "EST",
          },
        },
      ],
      usage: {
        "inputTokens" => 481,
        "outputTokens" => 28,
        "totalTokens" => 509,
      },
    }

    expected_request = {
      "system" => [{ "text" => "You are a helpful assistant." }],
      "messages" => [{ "role" => "user", "content" => [{ "text" => "what is the time in EST" }] }],
      "inferenceConfig" => {
        "max_new_tokens" => 200,
      },
      "toolConfig" => {
        "tools" => [
          {
            "toolSpec" => {
              "name" => "time",
              "description" => "Will look up the current time",
              "inputSchema" => {
                "json" => {
                  "type" => "object",
                  "required" => ["timezone"],
                  "properties" => {
                    "timezone" => {
                      "type" => "string",
                      "description" => "The timezone",
                    },
                  },
                },
              },
            },
          },
        ],
      },
    }

    with_scripted_responses([response_payload]) do |scripted_http|
      proxy = DiscourseAi::Completions::Llm.proxy(nova_model)
      response = []
      proxy.generate(prompt, user: user, max_tokens: 200) { |partial| response << partial }

      parsed_request = scripted_http.last_request
      expect(parsed_request).to eq(expected_request)
      expect(response).to eq(
        [
          DiscourseAi::Completions::ToolCall.new(
            name: "time",
            id: "e1bd7033-7244-4408-b088-1d33cbcf0b67",
            parameters: {
              "timezone" => "EST",
            },
          ),
        ],
      )
    end

    # lets continue and ensure all messages are mapped correctly
    prompt.push(type: :tool_call, name: "time", content: { timezone: "EST" }.to_json, id: "111")
    prompt.push(type: :tool, name: "time", content: "1pm".to_json, id: "111")

    # lets just return the tool call again, this is about ensuring we encode the prompt right
    expected_prompt = {
      system: [{ text: "You are a helpful assistant." }],
      messages: [
        { role: "user", content: [{ text: "what is the time in EST" }] },
        {
          role: "assistant",
          content: [{ toolUse: { toolUseId: "111", name: "time", input: nil } }],
        },
        {
          role: "user",
          content: [{ toolResult: { toolUseId: "111", content: [{ json: "1pm" }] } }],
        },
      ],
      inferenceConfig: {
        max_new_tokens: 200,
      },
      toolConfig: {
        tools: [
          {
            toolSpec: {
              name: "time",
              description: "Will look up the current time",
              inputSchema: {
                json: {
                  type: "object",
                  properties: {
                    timezone: {
                      type: "string",
                      description: "The timezone",
                    },
                  },
                  required: ["timezone"],
                },
              },
            },
          },
        ],
      },
    }

    with_scripted_responses([response_payload]) do |scripted_http|
      proxy = DiscourseAi::Completions::Llm.proxy(nova_model)
      response = []
      proxy.generate(prompt, user: user, max_tokens: 200) { |partial| response << partial }

      expect(scripted_http.last_request.deep_symbolize_keys).to eq(expected_prompt)
    end
  end
end
