# frozen_string_literal: true

require "aws-sdk-bedrockruntime"

RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrockConverse do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)
  fab!(:model, :bedrock_converse_model)

  before { enable_current_plugin }

  def mock_converse_response(text: "Hello world", input_tokens: 10, output_tokens: 5)
    response =
      Aws::BedrockRuntime::Types::ConverseResponse.new(
        output:
          Aws::BedrockRuntime::Types::ConverseOutput.new(
            message:
              Aws::BedrockRuntime::Types::Message.new(
                role: "assistant",
                content: [Aws::BedrockRuntime::Types::ContentBlock.new(text: text)],
              ),
          ),
        stop_reason: "end_turn",
        usage:
          Aws::BedrockRuntime::Types::TokenUsage.new(
            input_tokens: input_tokens,
            output_tokens: output_tokens,
          ),
      )
    response
  end

  def stub_sdk_client(response: nil, &stream_block)
    client = instance_double(Aws::BedrockRuntime::Client)

    allow(client).to receive(:converse).and_return(response) if response

    if stream_block
      allow(client).to receive(:converse_stream) do |params|
        handler = params[:event_stream_handler]
        listeners = handler.event_emitter.instance_variable_get(:@listeners)
        stream_block.call(listeners)
      end
    end

    allow(Aws::BedrockRuntime::Client).to receive(:new).and_return(client)
    client
  end

  def fire_event(listeners, type, event)
    listeners[type]&.each { |cb| cb.call(event) }
  end

  def fire_content_block_delta(listeners, text:, index: 0)
    event =
      Aws::BedrockRuntime::Types::ContentBlockDeltaEvent.new(
        delta: Aws::BedrockRuntime::Types::ContentBlockDelta.new(text: text),
        content_block_index: index,
      )
    fire_event(listeners, :content_block_delta, event)
  end

  def fire_content_block_stop(listeners, index: 0)
    event = Aws::BedrockRuntime::Types::ContentBlockStopEvent.new(content_block_index: index)
    fire_event(listeners, :content_block_stop, event)
  end

  def fire_message_start(listeners)
    event = Aws::BedrockRuntime::Types::MessageStartEvent.new(role: "assistant")
    fire_event(listeners, :message_start, event)
  end

  def fire_message_stop(listeners)
    event = Aws::BedrockRuntime::Types::MessageStopEvent.new(stop_reason: "end_turn")
    fire_event(listeners, :message_stop, event)
  end

  def fire_metadata(listeners, input_tokens: 10, output_tokens: 5)
    event =
      Aws::BedrockRuntime::Types::ConverseStreamMetadataEvent.new(
        usage:
          Aws::BedrockRuntime::Types::TokenUsage.new(
            input_tokens: input_tokens,
            output_tokens: output_tokens,
          ),
      )
    fire_event(listeners, :metadata, event)
  end

  describe "can_contact?" do
    it "returns true for aws_bedrock_converse provider" do
      expect(described_class.can_contact?(model)).to eq(true)
    end

    it "returns false for other providers" do
      model.provider = "aws_bedrock"
      expect(described_class.can_contact?(model)).to eq(false)
    end
  end

  describe "provider_id" do
    it "returns BedrockConverse" do
      expect(endpoint.provider_id).to eq(AiApiAuditLog::Provider::BedrockConverse)
    end
  end

  describe "default_options" do
    it "does not set max_tokens by default" do
      prompt = DiscourseAi::Completions::Prompt.new("hello")
      dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)

      expect(endpoint.default_options(dialect)).not_to have_key(:max_tokens)
    end

    it "configures adaptive thinking" do
      model.provider_params["enable_reasoning"] = true
      model.provider_params["adaptive_thinking"] = true

      prompt = DiscourseAi::Completions::Prompt.new("hello")
      dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)

      options = endpoint.default_options(dialect)
      expect(options[:thinking]).to eq({ type: "adaptive" })
    end

    it "configures reasoning with budget tokens" do
      model.provider_params["enable_reasoning"] = true
      model.provider_params["reasoning_tokens"] = 4096

      prompt = DiscourseAi::Completions::Prompt.new("hello")
      dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)

      options = endpoint.default_options(dialect)
      expect(options[:thinking]).to eq({ type: "enabled", budget_tokens: 4096 })
    end

    it "configures effort" do
      model.provider_params["effort"] = "high"

      prompt = DiscourseAi::Completions::Prompt.new("hello")
      dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)

      options = endpoint.default_options(dialect)
      expect(options[:output_config]).to eq({ effort: "high" })
    end
  end

  describe "non-streaming completion" do
    it "completes a simple prompt" do
      response = mock_converse_response(text: "Test response", input_tokens: 15, output_tokens: 8)
      client = stub_sdk_client(response: response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      result = llm.generate("hello", user: user)

      expect(result).to eq("Test response")
      expect(AiApiAuditLog.last.request_tokens).to eq(15)
      expect(AiApiAuditLog.last.response_tokens).to eq(8)
    end

    it "passes model name directly as model_id to SDK" do
      response = mock_converse_response
      client = stub_sdk_client(response: response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user)

      expect(client).to have_received(:converse) do |params|
        expect(params[:model_id]).to eq("claude-3-sonnet")
        expect(params[:system]).to be_present
      end
    end
  end

  describe "streaming completion" do
    it "streams text responses" do
      partials = []

      stub_sdk_client do |listeners|
        fire_message_start(listeners)
        fire_content_block_delta(listeners, text: "Hello")
        fire_content_block_delta(listeners, text: " ")
        fire_content_block_delta(listeners, text: "world")
        fire_content_block_stop(listeners)
        fire_message_stop(listeners)
        fire_metadata(listeners, input_tokens: 10, output_tokens: 3)
      end

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user) { |partial| partials << partial }

      expect(partials).to eq(["Hello", " ", "world"])
      expect(AiApiAuditLog.last.request_tokens).to eq(10)
      expect(AiApiAuditLog.last.response_tokens).to eq(3)
    end
  end

  describe "credential resolution" do
    it "uses static credentials when access_key_id is provided" do
      stub_sdk_client(response: mock_converse_response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user)

      expect(Aws::BedrockRuntime::Client).to have_received(:new) do |params|
        expect(params[:region]).to eq("us-east-1")
        expect(params[:credentials]).to be_an_instance_of(Aws::Credentials)
      end
    end

    it "uses role-based credentials when role_arn is provided" do
      model.update!(
        provider_params: {
          "role_arn" => "arn:aws:iam::123456:role/test",
          "region" => "us-east-1",
        },
      )

      sts_client = instance_double(Aws::STS::Client)
      allow(Aws::STS::Client).to receive(:new).and_return(sts_client)
      assume_role_creds = instance_double(Aws::AssumeRoleCredentials)
      allow(Aws::AssumeRoleCredentials).to receive(:new).and_return(assume_role_creds)

      stub_sdk_client(response: mock_converse_response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user)

      expect(Aws::BedrockRuntime::Client).to have_received(:new) do |params|
        expect(params[:credentials]).to eq(assume_role_creds)
      end
    end

    it "uses Bearer token auth when only api_key is provided" do
      model.update!(provider_params: { "region" => "us-east-1" }, api_key: "br-abc123")

      stub_sdk_client(response: mock_converse_response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user)

      expect(Aws::BedrockRuntime::Client).to have_received(:new) do |params|
        expect(params).not_to have_key(:credentials)
        expect(params[:token_provider]).to be_an_instance_of(Aws::StaticTokenProvider)
        expect(params[:token_provider].token.token).to eq("br-abc123")
      end
    end

    it "auto-resolves credentials when nothing is provided" do
      model.update!(provider_params: { "region" => "us-east-1" }, api_key: nil)

      stub_sdk_client(response: mock_converse_response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user)

      expect(Aws::BedrockRuntime::Client).to have_received(:new) do |params|
        expect(params).not_to have_key(:credentials)
        expect(params).not_to have_key(:token_provider)
      end
    end
  end

  describe "error handling" do
    it "raises CompletionFailed on SDK errors" do
      client = instance_double(Aws::BedrockRuntime::Client)
      allow(client).to receive(:converse).and_raise(
        Aws::BedrockRuntime::Errors::ThrottlingException.new(nil, "Rate exceeded"),
      )
      allow(Aws::BedrockRuntime::Client).to receive(:new).and_return(client)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      expect { llm.generate("hello", user: user) }.to raise_error(
        DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
      )
    end
  end
end
