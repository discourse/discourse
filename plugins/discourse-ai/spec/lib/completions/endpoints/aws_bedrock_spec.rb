# frozen_string_literal: true

require_relative "endpoint_compliance"
require "aws-eventstream"
require "aws-sigv4"

class BedrockMock < EndpointMock
end

RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrock do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)
  fab!(:model, :bedrock_model)

  let(:bedrock_mock) { BedrockMock.new(endpoint) }

  let(:compliance) do
    EndpointsCompliance.new(self, endpoint, DiscourseAi::Completions::Dialects::Claude, user)
  end

  def encode_message(message)
    wrapped = { bytes: Base64.encode64(message.to_json) }.to_json
    io = StringIO.new(wrapped)
    aws_message = Aws::EventStream::Message.new(payload: io)
    Aws::EventStream::Encoder.new.encode(aws_message)
  end

  before { enable_current_plugin }

  it "should provide accurate max token count" do
    prompt = DiscourseAi::Completions::Prompt.new("hello")
    dialect = DiscourseAi::Completions::Dialects::Claude.new(prompt, model)
    endpoint = DiscourseAi::Completions::Endpoints::AwsBedrock.new(model)

    model.name = "claude-2"
    expect(endpoint.default_options(dialect)[:max_tokens]).to eq(4096)

    model.name = "claude-3-5-sonnet"
    expect(endpoint.default_options(dialect)[:max_tokens]).to eq(8192)

    model.name = "claude-3-5-haiku"
    options = endpoint.default_options(dialect)
    expect(options[:max_tokens]).to eq(8192)
  end

  describe "function calling" do
    it "supports old school xml function calls" do
      model.provider_params["disable_native_tools"] = true
      model.save!

      proxy = DiscourseAi::Completions::Llm.proxy(model)

      incomplete_tool_call = <<~XML.strip
        <thinking>I should be ignored</thinking>
        <search_quality_reflection>also ignored</search_quality_reflection>
        <search_quality_score>0</search_quality_score>
        <function_calls>
        <invoke>
        <tool_name>google</tool_name>
        <parameters><query>sydney weather today</query></parameters>
        </invoke>
        </function_calls>
      XML

      messages =
        [
          { type: "message_start", message: { usage: { input_tokens: 9 } } },
          { type: "content_block_delta", delta: { text: "hello\n" } },
          { type: "content_block_delta", delta: { text: incomplete_tool_call } },
          { type: "message_delta", delta: { usage: { output_tokens: 25 } } },
        ].map { |message| encode_message(message) }

      request = nil
      bedrock_mock.with_chunk_array_support do
        stub_request(
          :post,
          "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke-with-response-stream",
        )
          .with do |inner_request|
            request = inner_request
            true
          end
          .to_return(status: 200, body: messages)

        prompt =
          DiscourseAi::Completions::Prompt.new(
            messages: [{ type: :user, content: "what is the weather in sydney" }],
          )

        tool = {
          name: "google",
          description: "Will search using Google",
          parameters: [
            { name: "query", description: "The search query", type: "string", required: true },
          ],
        }

        prompt.tools = [tool]
        response = []
        proxy.generate(prompt, user: user) { |partial| response << partial }

        expect(request.headers["Authorization"]).to be_present
        expect(request.headers["X-Amz-Content-Sha256"]).to be_present

        parsed_body = JSON.parse(request.body)
        expect(parsed_body["system"]).to include("<function_calls>")
        expect(parsed_body["tools"]).to eq(nil)
        expect(parsed_body["stop_sequences"]).to eq(["</function_calls>"])

        expected = [
          "hello\n",
          DiscourseAi::Completions::ToolCall.new(
            id: "tool_0",
            name: "google",
            parameters: {
              query: "sydney weather today",
            },
          ),
        ]

        expect(response).to eq(expected)
      end
    end

    it "supports streaming function calls" do
      proxy = DiscourseAi::Completions::Llm.proxy(model)

      request = nil

      messages =
        [
          {
            type: "message_start",
            message: {
              id: "msg_bdrk_01WYxeNMk6EKn9s98r6XXrAB",
              type: "message",
              role: "assistant",
              model: "claude-3-sonnet-20240307",
              stop_sequence: nil,
              usage: {
                input_tokens: 840,
                output_tokens: 1,
              },
              content: [],
              stop_reason: nil,
            },
          },
          {
            type: "content_block_start",
            index: 0,
            delta: {
              text: "<thinking>I should be ignored</thinking>",
            },
          },
          {
            type: "content_block_start",
            index: 0,
            content_block: {
              type: "tool_use",
              id: "toolu_bdrk_014CMjxtGmKUtGoEFPgc7PF7",
              name: "google",
              input: {
              },
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: "",
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: "{\"query\": \"s",
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: "ydney weat",
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: "her today\"}",
            },
          },
          { type: "content_block_stop", index: 0 },
          {
            type: "message_delta",
            delta: {
              stop_reason: "tool_use",
              stop_sequence: nil,
            },
            usage: {
              output_tokens: 53,
            },
          },
          {
            type: "message_stop",
            "amazon-bedrock-invocationMetrics": {
              inputTokenCount: 846,
              outputTokenCount: 39,
              invocationLatency: 880,
              firstByteLatency: 402,
            },
          },
        ].map { |message| encode_message(message) }

      messages = messages.join("").split

      bedrock_mock.with_chunk_array_support do
        stub_request(
          :post,
          "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke-with-response-stream",
        )
          .with do |inner_request|
            request = inner_request
            true
          end
          .to_return(status: 200, body: messages)

        prompt =
          DiscourseAi::Completions::Prompt.new(
            messages: [{ type: :user, content: "what is the weather in sydney" }],
          )

        tool = {
          name: "google",
          description: "Will search using Google",
          parameters: [
            { name: "query", description: "The search query", type: "string", required: true },
          ],
        }

        prompt.tools = [tool]
        response = []
        proxy.generate(prompt, user: user) { |partial| response << partial }

        expect(request.headers["Authorization"]).to be_present
        expect(request.headers["X-Amz-Content-Sha256"]).to be_present

        expected_response = [
          DiscourseAi::Completions::ToolCall.new(
            id: "toolu_bdrk_014CMjxtGmKUtGoEFPgc7PF7",
            name: "google",
            parameters: {
              query: "sydney weather today",
            },
          ),
        ]

        expect(response).to eq(expected_response)

        expected = {
          "max_tokens" => 4096,
          "anthropic_version" => "bedrock-2023-05-31",
          "messages" => [{ "role" => "user", "content" => "what is the weather in sydney" }],
          "tools" => [
            {
              "name" => "google",
              "description" => "Will search using Google",
              "input_schema" => {
                "type" => "object",
                "properties" => {
                  "query" => {
                    "type" => "string",
                    "description" => "The search query",
                  },
                },
                "required" => ["query"],
              },
            },
          ],
        }
        expect(JSON.parse(request.body)).to eq(expected)

        log = AiApiAuditLog.order(:id).last
        expect(log.request_tokens).to eq(846)
        expect(log.response_tokens).to eq(39)
      end
    end
  end

  describe "Claude 3 support" do
    it "supports regular completions" do
      proxy = DiscourseAi::Completions::Llm.proxy(model)

      request = nil

      content = {
        content: [text: "hello sam"],
        usage: {
          input_tokens: 10,
          output_tokens: 20,
        },
      }.to_json

      stub_request(
        :post,
        "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke",
      )
        .with do |inner_request|
          request = inner_request
          true
        end
        .to_return(status: 200, body: content)

      response = proxy.generate("hello world", user: user)

      expect(request.headers["Authorization"]).to be_present
      expect(request.headers["X-Amz-Content-Sha256"]).to be_present

      expected = {
        "max_tokens" => 4096,
        "anthropic_version" => "bedrock-2023-05-31",
        "messages" => [{ "role" => "user", "content" => "hello world" }],
        "system" => "You are a helpful bot",
      }
      expect(JSON.parse(request.body)).to eq(expected)

      expect(response).to eq("hello sam")

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(10)
      expect(log.response_tokens).to eq(20)
    end

    it "supports thinking" do
      model.provider_params["enable_reasoning"] = true
      model.provider_params["reasoning_tokens"] = 10_000
      model.save!

      proxy = DiscourseAi::Completions::Llm.proxy(model)

      request = nil

      content = {
        content: [text: "hello sam"],
        usage: {
          input_tokens: 10,
          output_tokens: 20,
        },
      }.to_json

      stub_request(
        :post,
        "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke",
      )
        .with do |inner_request|
          request = inner_request
          true
        end
        .to_return(status: 200, body: content)

      response = proxy.generate("hello world", user: user)

      expect(request.headers["Authorization"]).to be_present
      expect(request.headers["X-Amz-Content-Sha256"]).to be_present

      expected = {
        "max_tokens" => 40_000,
        "thinking" => {
          "type" => "enabled",
          "budget_tokens" => 10_000,
        },
        "anthropic_version" => "bedrock-2023-05-31",
        "messages" => [{ "role" => "user", "content" => "hello world" }],
        "system" => "You are a helpful bot",
      }
      expect(JSON.parse(request.body)).to eq(expected)

      expect(response).to eq("hello sam")

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(10)
      expect(log.response_tokens).to eq(20)
    end

    it "supports claude 3 streaming" do
      proxy = DiscourseAi::Completions::Llm.proxy(model)

      request = nil

      messages =
        [
          { type: "message_start", message: { usage: { input_tokens: 9 } } },
          { type: "content_block_delta", delta: { text: "hello " } },
          { type: "content_block_delta", delta: { text: "sam" } },
          { type: "message_delta", delta: { usage: { output_tokens: 25 } } },
        ].map { |message| encode_message(message) }

      # stream 1 letter at a time
      # cause we need to handle this case
      messages = messages.join("").split

      bedrock_mock.with_chunk_array_support do
        stub_request(
          :post,
          "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke-with-response-stream",
        )
          .with do |inner_request|
            request = inner_request
            true
          end
          .to_return(status: 200, body: messages)

        response = +""
        proxy.generate("hello world", user: user) { |partial| response << partial }

        expect(request.headers["Authorization"]).to be_present
        expect(request.headers["X-Amz-Content-Sha256"]).to be_present

        expected = {
          "max_tokens" => 4096,
          "anthropic_version" => "bedrock-2023-05-31",
          "messages" => [{ "role" => "user", "content" => "hello world" }],
          "system" => "You are a helpful bot",
        }
        expect(JSON.parse(request.body)).to eq(expected)

        expect(response).to eq("hello sam")

        log = AiApiAuditLog.order(:id).last
        expect(log.request_tokens).to eq(9)
        expect(log.response_tokens).to eq(25)
      end
    end
  end

  describe "parameter disabling" do
    it "excludes disabled parameters from the request" do
      model.update!(
        provider_params: {
          access_key_id: "123",
          region: "us-east-1",
          disable_top_p: true,
          disable_temperature: true,
        },
      )

      proxy = DiscourseAi::Completions::Llm.proxy(model)
      request = nil

      content = {
        content: [text: "test response"],
        usage: {
          input_tokens: 10,
          output_tokens: 5,
        },
      }.to_json

      stub_request(
        :post,
        "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke",
      )
        .with do |inner_request|
          request = inner_request
          true
        end
        .to_return(status: 200, body: content)

      # Request with parameters that should be ignored
      proxy.generate("test prompt", user: user, top_p: 0.9, temperature: 0.8, max_tokens: 500)

      # Parse the request body
      request_body = JSON.parse(request.body)

      # Verify disabled parameters aren't included
      expect(request_body).not_to have_key("top_p")
      expect(request_body).not_to have_key("temperature")

      # Verify other parameters still work
      expect(request_body).to have_key("max_tokens")
      expect(request_body["max_tokens"]).to eq(500)
    end
  end

  describe "disabled tool use" do
    it "handles tool_choice: :none by adding a prefill message instead of using tool_choice param" do
      proxy = DiscourseAi::Completions::Llm.proxy(model)
      request = nil

      # Create a prompt with tool_choice: :none
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a helpful assistant",
          messages: [{ type: :user, content: "don't use any tools please" }],
          tools: [
            {
              name: "echo",
              description: "echo something",
              parameters: [
                { name: "text", type: "string", description: "text to echo", required: true },
              ],
            },
          ],
          tool_choice: :none,
        )

      # Mock response from Bedrock
      content = {
        content: [text: "I won't use any tools. Here's a direct response instead."],
        usage: {
          input_tokens: 25,
          output_tokens: 15,
        },
      }.to_json

      stub_request(
        :post,
        "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke",
      )
        .with do |inner_request|
          request = inner_request
          true
        end
        .to_return(status: 200, body: content)

      proxy.generate(prompt, user: user)

      # Parse the request body
      request_body = JSON.parse(request.body)

      # Verify that tool_choice is NOT present (not supported in Bedrock)
      expect(request_body).not_to have_key("tool_choice")

      # Verify that an assistant message was added with no_more_tool_calls_text
      messages = request_body["messages"]
      expect(messages.length).to eq(2) # user message + added assistant message

      last_message = messages.last
      expect(last_message["role"]).to eq("assistant")

      expect(last_message["content"]).to eq(
        DiscourseAi::Completions::Dialects::Dialect.no_more_tool_calls_text,
      )
    end
  end

  describe "forced tool use" do
    it "can properly force tool use" do
      proxy = DiscourseAi::Completions::Llm.proxy(model)
      request = nil

      tools = [
        {
          name: "echo",
          description: "echo something",
          parameters: [
            { name: "text", type: "string", description: "text to echo", required: true },
          ],
        },
      ]

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [type: :user, id: "user1", content: "echo hello"],
          tools: tools,
          tool_choice: "echo",
        )

      # Mock response from Bedrock
      content = {
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
        usage: {
          input_tokens: 25,
          output_tokens: 15,
        },
      }.to_json

      stub_request(
        :post,
        "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke",
      )
        .with do |inner_request|
          request = inner_request
          true
        end
        .to_return(status: 200, body: content)

      proxy.generate(prompt, user: user)

      # Parse the request body
      request_body = JSON.parse(request.body)

      # Verify that tool_choice: "echo" is present
      expect(request_body.dig("tool_choice", "name")).to eq("echo")
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

      messages =
        [
          { type: "message_start", message: { usage: { input_tokens: 9 } } },
          { type: "content_block_delta", delta: { text: "\"" } },
          { type: "content_block_delta", delta: { text: "key" } },
          { type: "content_block_delta", delta: { text: "\":\"" } },
          { type: "content_block_delta", delta: { text: "Hello!" } },
          { type: "content_block_delta", delta: { text: "\n There" } },
          { type: "content_block_delta", delta: { text: "\"}" } },
          { type: "message_delta", delta: { usage: { output_tokens: 25 } } },
        ].map { |message| encode_message(message) }

      proxy = DiscourseAi::Completions::Llm.proxy(model)
      request = nil
      bedrock_mock.with_chunk_array_support do
        stub_request(
          :post,
          "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke-with-response-stream",
        )
          .with do |inner_request|
            request = inner_request
            true
          end
          .to_return(status: 200, body: messages)

        structured_output = nil
        proxy.generate("hello world", response_format: schema, user: user) do |partial|
          structured_output = partial
        end

        expected = {
          "max_tokens" => 4096,
          "anthropic_version" => "bedrock-2023-05-31",
          "messages" => [
            { "role" => "user", "content" => "hello world" },
            { "role" => "assistant", "content" => "{" },
          ],
          "system" => "You are a helpful bot",
        }
        expect(JSON.parse(request.body)).to eq(expected)

        expect(structured_output.read_buffered_property(:key)).to eq("Hello!\n There")
      end
    end

    it "works with JSON schema array types" do
      schema = {
        type: "json_schema",
        json_schema: {
          name: "reply",
          schema: {
            type: "object",
            properties: {
              plain: {
                type: "string",
              },
              key: {
                type: "array",
                items: {
                  type: "string",
                },
              },
            },
            required: %w[plain key],
            additionalProperties: false,
          },
          strict: true,
        },
      }

      messages =
        [
          { type: "message_start", message: { usage: { input_tokens: 9 } } },
          { type: "content_block_delta", delta: { text: "\"" } },
          { type: "content_block_delta", delta: { text: "key" } },
          { type: "content_block_delta", delta: { text: "\":" } },
          { type: "content_block_delta", delta: { text: " [\"" } },
          { type: "content_block_delta", delta: { text: "Hello!" } },
          { type: "content_block_delta", delta: { text: " I am" } },
          { type: "content_block_delta", delta: { text: " a " } },
          { type: "content_block_delta", delta: { text: "chunk\"," } },
          { type: "content_block_delta", delta: { text: "\"There" } },
          { type: "content_block_delta", delta: { text: "\"]," } },
          { type: "content_block_delta", delta: { text: " \"plain" } },
          { type: "content_block_delta", delta: { text: "\":\"" } },
          { type: "content_block_delta", delta: { text: "I'm here" } },
          { type: "content_block_delta", delta: { text: " too\"}" } },
          { type: "message_delta", delta: { usage: { output_tokens: 25 } } },
        ].map { |message| encode_message(message) }

      proxy = DiscourseAi::Completions::Llm.proxy(model)
      request = nil
      bedrock_mock.with_chunk_array_support do
        stub_request(
          :post,
          "https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke-with-response-stream",
        )
          .with do |inner_request|
            request = inner_request
            true
          end
          .to_return(status: 200, body: messages)

        structured_output = nil
        proxy.generate("hello world", response_format: schema, user: user) do |partial|
          structured_output = partial
        end

        expected = {
          "max_tokens" => 4096,
          "anthropic_version" => "bedrock-2023-05-31",
          "messages" => [
            { "role" => "user", "content" => "hello world" },
            { "role" => "assistant", "content" => "{" },
          ],
          "system" => "You are a helpful bot",
        }
        expect(JSON.parse(request.body)).to eq(expected)

        expect(structured_output.read_buffered_property(:key)).to contain_exactly(
          "Hello! I am a chunk",
          "There",
        )
        expect(structured_output.read_buffered_property(:plain)).to eq("I'm here too")
      end
    end
  end
end
