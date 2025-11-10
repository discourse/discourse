# frozen_string_literal: true

require_relative "endpoint_compliance"
require "aws-eventstream"
require "aws-sigv4"
require "aws-sdk-sts"

RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrock do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)
  fab!(:model, :bedrock_model)

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

  def with_scripted_responses(responses, llm_model: model, &block)
    DiscourseAi::Completions::Llm.with_prepared_responses(
      responses,
      llm: llm_model,
      transport: :scripted_http,
      &block
    )
  end

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

      with_scripted_responses([{ raw_stream: messages }]) do |scripted_http|
        proxy = DiscourseAi::Completions::Llm.proxy(model)
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

        headers = scripted_http.last_request_headers
        expect(headers["authorization"]).to be_present
        expect(headers["x-amz-content-sha256"]).to be_present

        parsed_body = scripted_http.last_request
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
      scripted_response = {
        tool_calls: [
          {
            id: "toolu_bdrk_014CMjxtGmKUtGoEFPgc7PF7",
            name: "google",
            arguments: {
              query: "sydney weather today",
            },
          },
        ],
        usage: {
          input_tokens: 846,
          output_tokens: 39,
        },
      }

      with_scripted_responses([scripted_response]) do |scripted_http|
        proxy = DiscourseAi::Completions::Llm.proxy(model)
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

        headers = scripted_http.last_request_headers
        expect(headers["authorization"]).to be_present
        expect(headers["x-amz-content-sha256"]).to be_present

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
        expect(scripted_http.last_request).to eq(expected)

        log = AiApiAuditLog.order(:id).last
        expect(log.request_tokens).to eq(846)
        expect(log.response_tokens).to eq(39)
      end
    end
  end

  describe "Claude 3 support" do
    it "supports regular completions" do
      payload = { content: "hello sam", usage: { input_tokens: 10, output_tokens: 20 } }

      response =
        with_scripted_responses([payload]) do |scripted_http|
          proxy = DiscourseAi::Completions::Llm.proxy(model)
          result = proxy.generate("hello world", user: user)

          headers = scripted_http.last_request_headers
          expect(headers["authorization"]).to be_present
          expect(headers["x-amz-content-sha256"]).to be_present

          expected = {
            "max_tokens" => 4096,
            "anthropic_version" => "bedrock-2023-05-31",
            "messages" => [{ "role" => "user", "content" => "hello world" }],
            "system" => "You are a helpful bot",
          }
          expect(scripted_http.last_request).to eq(expected)

          result
        end

      expect(response).to eq("hello sam")

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(10)
      expect(log.response_tokens).to eq(20)
    end

    it "supports thinking" do
      model.provider_params["enable_reasoning"] = true
      model.provider_params["reasoning_tokens"] = 10_000
      model.save!

      payload = { content: "hello sam", usage: { input_tokens: 10, output_tokens: 20 } }

      response =
        with_scripted_responses([payload]) do |scripted_http|
          proxy = DiscourseAi::Completions::Llm.proxy(model)
          result = proxy.generate("hello world", user: user)

          headers = scripted_http.last_request_headers
          expect(headers["authorization"]).to be_present
          expect(headers["x-amz-content-sha256"]).to be_present

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
          expect(scripted_http.last_request).to eq(expected)

          result
        end

      expect(response).to eq("hello sam")

      log = AiApiAuditLog.order(:id).last
      expect(log.request_tokens).to eq(10)
      expect(log.response_tokens).to eq(20)
    end

    it "supports claude 3 streaming" do
      payload = { content: "hello sam", usage: { input_tokens: 9, output_tokens: 25 } }

      with_scripted_responses([payload]) do |scripted_http|
        proxy = DiscourseAi::Completions::Llm.proxy(model)
        response = +""
        proxy.generate("hello world", user: user) { |partial| response << partial }

        headers = scripted_http.last_request_headers
        expect(headers["authorization"]).to be_present
        expect(headers["x-amz-content-sha256"]).to be_present

        expected = {
          "max_tokens" => 4096,
          "anthropic_version" => "bedrock-2023-05-31",
          "messages" => [{ "role" => "user", "content" => "hello world" }],
          "system" => "You are a helpful bot",
        }
        expect(scripted_http.last_request).to eq(expected)

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

      with_scripted_responses(["ok"]) do |scripted_http|
        proxy = DiscourseAi::Completions::Llm.proxy(model)

        # Request with parameters that should be ignored
        proxy.generate("test prompt", user: user, top_p: 0.9, temperature: 0.8, max_tokens: 500)

        # Parse the request body
        request_body = scripted_http.last_request

        # Verify disabled parameters aren't included
        expect(request_body).not_to have_key("top_p")
        expect(request_body).not_to have_key("temperature")

        # Verify other parameters still work
        expect(request_body).to have_key("max_tokens")
        expect(request_body["max_tokens"]).to eq(500)
      end
    end
  end

  describe "disabled tool use" do
    it "handles tool_choice: :none by adding a prefill message instead of using tool_choice param" do
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

      payload = {
        content: "I won't use any tools. Here's a direct response instead.",
        usage: {
          input_tokens: 25,
          output_tokens: 15,
        },
      }

      with_scripted_responses([payload]) do |scripted_http|
        proxy = DiscourseAi::Completions::Llm.proxy(model)
        proxy.generate(prompt, user: user)

        request_body = scripted_http.last_request
        expect(request_body).not_to have_key("tool_choice")

        messages = request_body["messages"]
        expect(messages.length).to eq(2)

        last_message = messages.last
        expect(last_message["role"]).to eq("assistant")
        expect(last_message["content"]).to eq(
          DiscourseAi::Completions::Dialects::Dialect.no_more_tool_calls_text,
        )
      end
    end
  end

  describe "forced tool use" do
    it "can properly force tool use" do
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
      payload = {
        tool_calls: [
          { id: "toolu_bdrk_014CMjxtGmKUtGoEFPgc7PF7", name: "echo", arguments: { text: "hello" } },
        ],
        usage: {
          input_tokens: 25,
          output_tokens: 15,
        },
      }

      with_scripted_responses([payload]) do |scripted_http|
        proxy = DiscourseAi::Completions::Llm.proxy(model)
        proxy.generate(prompt, user: user)

        request_body = scripted_http.last_request
        expect(request_body.dig("tool_choice", "name")).to eq("echo")
      end
    end
  end

  describe "role-based authentication" do
    it "uses assumed role credentials when role_arn is provided" do
      # Configure the model with a role_arn
      model.update!(
        provider_params: {
          region: "us-east-1",
          role_arn: "arn:aws:iam::123456789012:role/BedRockAccessRole",
        },
      )

      # Mock the actual credentials object returned by AssumeRoleCredentials
      mock_creds =
        instance_double(
          Aws::Credentials,
          access_key_id: "ASSUMED_ACCESS_KEY",
          secret_access_key: "ASSUMED_SECRET_KEY",
          session_token: "ASSUMED_SESSION_TOKEN",
        )

      # Mock Aws::AssumeRoleCredentials
      mock_credentials = instance_double(Aws::AssumeRoleCredentials)
      allow(mock_credentials).to receive(:credentials).and_return(mock_creds)

      # Mock the STS client
      mock_sts_client = instance_double(Aws::STS::Client)
      allow(Aws::STS::Client).to receive(:new).with(region: "us-east-1").and_return(mock_sts_client)

      # Mock AssumeRoleCredentials.new
      allow(Aws::AssumeRoleCredentials).to receive(:new).with(
        role_arn: "arn:aws:iam::123456789012:role/BedRockAccessRole",
        role_session_name: "discourse-bedrock-#{Process.pid}",
        client: mock_sts_client,
      ).and_return(mock_credentials)

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

      proxy.generate("test prompt", user: user)

      # Verify AssumeRoleCredentials was created with correct parameters
      expect(Aws::AssumeRoleCredentials).to have_received(:new).with(
        role_arn: "arn:aws:iam::123456789012:role/BedRockAccessRole",
        role_session_name: "discourse-bedrock-#{Process.pid}",
        client: mock_sts_client,
      )

      # Verify the request was signed (authorization header should be present)
      expect(request.headers["Authorization"]).to be_present
      expect(request.headers["X-Amz-Content-Sha256"]).to be_present
      # The session token should be included in the signed request headers
      expect(request.headers["X-Amz-Security-Token"]).to eq("ASSUMED_SESSION_TOKEN")
    end

    it "uses regular credentials when role_arn is not provided" do
      # Configure the model without a role_arn
      model.update!(provider_params: { access_key_id: "DIRECT_ACCESS_KEY", region: "us-east-1" })

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

      # Ensure AssumeRoleCredentials is not used when role_arn is not provided
      allow(Aws::AssumeRoleCredentials).to receive(:new).and_call_original

      proxy.generate("test prompt", user: user)

      expect(Aws::AssumeRoleCredentials).not_to have_received(:new)

      # Verify the request was signed with regular credentials
      expect(request.headers["Authorization"]).to be_present
      expect(request.headers["X-Amz-Content-Sha256"]).to be_present
      # No session token should be present when using regular credentials
      expect(request.headers["X-Amz-Security-Token"]).to be_nil
    end

    it "caches assumed role credentials across multiple requests" do
      # Configure the model with a role_arn
      model.update!(
        provider_params: {
          region: "us-east-1",
          role_arn: "arn:aws:iam::123456789012:role/BedRockAccessRole",
        },
      )

      # Mock the actual credentials object returned by AssumeRoleCredentials
      mock_creds =
        instance_double(
          Aws::Credentials,
          access_key_id: "ASSUMED_ACCESS_KEY",
          secret_access_key: "ASSUMED_SECRET_KEY",
          session_token: "ASSUMED_SESSION_TOKEN",
        )

      # Mock Aws::AssumeRoleCredentials
      mock_credentials = instance_double(Aws::AssumeRoleCredentials)
      allow(mock_credentials).to receive(:credentials).and_return(mock_creds)

      # Mock the STS client
      mock_sts_client = instance_double(Aws::STS::Client)
      allow(Aws::STS::Client).to receive(:new).with(region: "us-east-1").and_return(mock_sts_client)

      # Mock AssumeRoleCredentials.new
      allow(Aws::AssumeRoleCredentials).to receive(:new).with(
        role_arn: "arn:aws:iam::123456789012:role/BedRockAccessRole",
        role_session_name: "discourse-bedrock-#{Process.pid}",
        client: mock_sts_client,
      ).and_return(mock_credentials)

      proxy = DiscourseAi::Completions::Llm.proxy(model)

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
      ).to_return(status: 200, body: content)

      # Make multiple generate calls
      proxy.generate("test prompt 1", user: user)
      proxy.generate("test prompt 2", user: user)
      proxy.generate("test prompt 3", user: user)

      # Verify AssumeRoleCredentials was created only once (cached in LlmModel)
      expect(Aws::AssumeRoleCredentials).to have_received(:new).once
    end

    it "invalidates cache when role_arn changes" do
      # Configure the model with initial role_arn
      model.update!(
        provider_params: {
          region: "us-east-1",
          role_arn: "arn:aws:iam::123456789012:role/FirstRole",
        },
      )

      # Mock credentials for first role
      mock_creds_1 =
        instance_double(
          Aws::Credentials,
          access_key_id: "FIRST_ACCESS_KEY",
          secret_access_key: "FIRST_SECRET_KEY",
          session_token: "FIRST_SESSION_TOKEN",
        )
      mock_credentials_1 = instance_double(Aws::AssumeRoleCredentials)
      allow(mock_credentials_1).to receive(:credentials).and_return(mock_creds_1)

      # Mock credentials for second role
      mock_creds_2 =
        instance_double(
          Aws::Credentials,
          access_key_id: "SECOND_ACCESS_KEY",
          secret_access_key: "SECOND_SECRET_KEY",
          session_token: "SECOND_SESSION_TOKEN",
        )
      mock_credentials_2 = instance_double(Aws::AssumeRoleCredentials)
      allow(mock_credentials_2).to receive(:credentials).and_return(mock_creds_2)

      mock_sts_client = instance_double(Aws::STS::Client)
      allow(Aws::STS::Client).to receive(:new).with(region: "us-east-1").and_return(mock_sts_client)

      # Mock AssumeRoleCredentials.new to return different credentials based on role_arn
      allow(Aws::AssumeRoleCredentials).to receive(:new).with(
        role_arn: "arn:aws:iam::123456789012:role/FirstRole",
        role_session_name: "discourse-bedrock-#{Process.pid}",
        client: mock_sts_client,
      ).and_return(mock_credentials_1)

      allow(Aws::AssumeRoleCredentials).to receive(:new).with(
        role_arn: "arn:aws:iam::123456789012:role/SecondRole",
        role_session_name: "discourse-bedrock-#{Process.pid}",
        client: mock_sts_client,
      ).and_return(mock_credentials_2)

      proxy = DiscourseAi::Completions::Llm.proxy(model)

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
      ).to_return(status: 200, body: content)

      # First request with initial role
      proxy.generate("test prompt 1", user: user)

      # Change the role_arn
      model.update!(
        provider_params: {
          region: "us-east-1",
          role_arn: "arn:aws:iam::123456789012:role/SecondRole",
        },
      )

      # Second request should use new role
      proxy.generate("test prompt 2", user: user)

      # Verify AssumeRoleCredentials was created twice (once for each role)
      expect(Aws::AssumeRoleCredentials).to have_received(:new).with(
        role_arn: "arn:aws:iam::123456789012:role/FirstRole",
        role_session_name: "discourse-bedrock-#{Process.pid}",
        client: mock_sts_client,
      ).once

      expect(Aws::AssumeRoleCredentials).to have_received(:new).with(
        role_arn: "arn:aws:iam::123456789012:role/SecondRole",
        role_session_name: "discourse-bedrock-#{Process.pid}",
        client: mock_sts_client,
      ).once
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

      payload = {
        content_blocks: [{ type: :text, text_chunks: ["\"key\":\"Hello!\\n There\"}"] }],
        usage: {
          input_tokens: 9,
          output_tokens: 25,
        },
      }

      structured_output = nil

      with_scripted_responses([payload]) do |scripted_http|
        proxy = DiscourseAi::Completions::Llm.proxy(model)
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
        expect(scripted_http.last_request).to eq(expected)
      end

      expect(structured_output.read_buffered_property(:key)).to eq("Hello!\n There")
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

      payload = {
        content_blocks: [
          {
            type: :text,
            text_chunks: [
              "\"key\":[\"Hello! I am a chunk\",",
              "\"There\"],\"plain\":\"I'm here too\"}",
            ],
          },
        ],
        usage: {
          input_tokens: 9,
          output_tokens: 25,
        },
      }

      structured_output = nil

      with_scripted_responses([payload]) do |scripted_http|
        proxy = DiscourseAi::Completions::Llm.proxy(model)
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
        expect(scripted_http.last_request).to eq(expected)
      end

      expect(structured_output.read_buffered_property(:key)).to contain_exactly(
        "Hello! I am a chunk",
        "There",
      )
      expect(structured_output.read_buffered_property(:plain)).to eq("I'm here too")
    end
  end
end
