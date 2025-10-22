# frozen_string_literal: true

require_relative "endpoint_compliance"
require "aws-eventstream"
require "aws-sigv4"

class BedrockMock < EndpointMock
end

# nova is all implemented in bedrock endpoint, split out here
RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrock do
  fab!(:user)
  fab!(:nova_model)

  subject(:endpoint) { described_class.new(nova_model) }

  let(:bedrock_mock) { BedrockMock.new(endpoint) }

  let(:stream_url) do
    "https://bedrock-runtime.us-east-1.amazonaws.com/model/amazon.nova-pro-v1:0/invoke-with-response-stream"
  end

  def encode_message(message)
    wrapped = { bytes: Base64.encode64(message.to_json) }.to_json
    io = StringIO.new(wrapped)
    aws_message = Aws::EventStream::Message.new(payload: io)
    Aws::EventStream::Encoder.new.encode(aws_message)
  end

  before { enable_current_plugin }

  it "should be able to make a simple request" do
    proxy = DiscourseAi::Completions::Llm.proxy(nova_model)

    content = {
      "output" => {
        "message" => {
          "content" => [{ "text" => "it is 2." }],
          "role" => "assistant",
        },
      },
      "stopReason" => "end_turn",
      "usage" => {
        "inputTokens" => 14,
        "outputTokens" => 119,
        "totalTokens" => 133,
        "cacheReadInputTokenCount" => nil,
        "cacheWriteInputTokenCount" => nil,
      },
    }.to_json

    stub_request(
      :post,
      "https://bedrock-runtime.us-east-1.amazonaws.com/model/amazon.nova-pro-v1:0/invoke",
    ).to_return(status: 200, body: content)

    response = proxy.generate("hello world", user: user)
    expect(response).to eq("it is 2.")

    log = AiApiAuditLog.order(:id).last
    expect(log.request_tokens).to eq(14)
    expect(log.response_tokens).to eq(119)
  end

  it "should be able to make a streaming request" do
    messages =
      [
        { messageStart: { role: "assistant" } },
        { contentBlockDelta: { delta: { text: "Hello" }, contentBlockIndex: 0 } },
        { contentBlockStop: { contentBlockIndex: 0 } },
        { contentBlockDelta: { delta: { text: "!" }, contentBlockIndex: 1 } },
        { contentBlockStop: { contentBlockIndex: 1 } },
        {
          metadata: {
            usage: {
              inputTokens: 14,
              outputTokens: 18,
            },
            metrics: {
            },
            trace: {
            },
          },
          "amazon-bedrock-invocationMetrics": {
            inputTokenCount: 14,
            outputTokenCount: 18,
            invocationLatency: 402,
            firstByteLatency: 72,
          },
        },
      ].map { |message| encode_message(message) }

    stub_request(:post, stream_url).to_return(status: 200, body: messages.join)

    proxy = DiscourseAi::Completions::Llm.proxy(nova_model)
    responses = []
    proxy.generate("Hello!", user: user) { |partial| responses << partial }

    expect(responses).to eq(%w[Hello !])
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

    messages =
      [
        { messageStart: { role: "assistant" } },
        {
          contentBlockStart: {
            start: {
              toolUse: {
                toolUseId: "e1bd7033-7244-4408-b088-1d33cbcf0b67",
                name: "time",
              },
            },
            contentBlockIndex: 0,
          },
        },
        {
          contentBlockDelta: {
            delta: {
              toolUse: {
                input: "{\"timezone\":\"EST\"}",
              },
            },
            contentBlockIndex: 0,
          },
        },
        { contentBlockStop: { contentBlockIndex: 0 } },
        { messageStop: { stopReason: "end_turn" } },
        {
          metadata: {
            usage: {
              inputTokens: 481,
              outputTokens: 28,
            },
            metrics: {
            },
            trace: {
            },
          },
          "amazon-bedrock-invocationMetrics": {
            inputTokenCount: 481,
            outputTokenCount: 28,
            invocationLatency: 383,
            firstByteLatency: 57,
          },
        },
      ].map { |message| encode_message(message) }

    request = nil
    stub_request(:post, stream_url)
      .with do |inner_request|
        request = inner_request
        true
      end
      .to_return(status: 200, body: messages)

    response = []
    bedrock_mock.with_chunk_array_support do
      proxy.generate(prompt, user: user, max_tokens: 200) { |partial| response << partial }
    end

    parsed_request = JSON.parse(request.body)
    expected = {
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

    expect(parsed_request).to eq(expected)
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

    # lets continue and ensure all messages are mapped correctly
    prompt.push(type: :tool_call, name: "time", content: { timezone: "EST" }.to_json, id: "111")
    prompt.push(type: :tool, name: "time", content: "1pm".to_json, id: "111")

    # lets just return the tool call again, this is about ensuring we encode the prompt right
    stub_request(:post, stream_url)
      .with do |inner_request|
        request = inner_request
        true
      end
      .to_return(status: 200, body: messages)

    response = []
    bedrock_mock.with_chunk_array_support do
      proxy.generate(prompt, user: user, max_tokens: 200) { |partial| response << partial }
    end

    expected = {
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

    expect(JSON.parse(request.body, symbolize_names: true)).to eq(expected)
  end
end
