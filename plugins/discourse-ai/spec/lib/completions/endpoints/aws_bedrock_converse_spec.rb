# frozen_string_literal: true

require "aws-sdk-bedrockruntime"

RSpec.describe DiscourseAi::Completions::Endpoints::AwsBedrockConverse do
  subject(:endpoint) { described_class.new(model) }

  fab!(:user)
  fab!(:model, :bedrock_converse_model)

  before { enable_current_plugin }

  it "captures streamed truncation with SDK snake-case metadata" do
    stub_sdk_client do |listeners|
      fire_message_start(listeners)
      fire_content_block_delta(listeners, text: "Answer")
      fire_event(
        listeners,
        :message_stop,
        Aws::BedrockRuntime::Types::MessageStopEvent.new(stop_reason: "max_tokens"),
      )
      fire_metadata(listeners)
    end
    model.to_llm.generate("Input", user: user) { |partial| }
    expect(AiApiAuditLog.last).to have_attributes(
      stop_reason: "max_tokens",
      completion_state: AiApiAuditLog::CompletionState::TRUNCATED,
    )
  end

  it "captures streamed normal completion with SDK snake-case metadata" do
    stub_sdk_client do |listeners|
      fire_message_start(listeners)
      fire_content_block_delta(listeners, text: "Answer")
      fire_event(
        listeners,
        :message_stop,
        Aws::BedrockRuntime::Types::MessageStopEvent.new(stop_reason: "end_turn"),
      )
      fire_metadata(listeners)
    end
    model.to_llm.generate("Input", user: user) { |partial| }
    expect(AiApiAuditLog.last).to have_attributes(
      stop_reason: "end_turn",
      completion_state: AiApiAuditLog::CompletionState::COMPLETE,
    )
  end

  describe "completion metadata" do
    it "records SDK stop reasons and limits in non-streaming responses" do
      response = mock_converse_response(text: "Partial")
      response.stop_reason = "max_tokens"
      stub_sdk_client(response: response)
      model.to_llm.generate("Input", user: user)
      expect(AiApiAuditLog.last).to have_attributes(
        completion_state: AiApiAuditLog::CompletionState::TRUNCATED,
        stop_reason: "max_tokens",
        reasoning_tokens: nil,
      )
    end

    it "forwards streamed message-stop reasons even without content" do
      stub_sdk_client do |listeners|
        fire_message_start(listeners)
        fire_event(
          listeners,
          :message_stop,
          Aws::BedrockRuntime::Types::MessageStopEvent.new(stop_reason: "max_tokens"),
        )
        fire_metadata(listeners, output_tokens: 100)
      end
      model.to_llm.generate("Input", user: user) { |partial| }
      expect(AiApiAuditLog.last).to have_attributes(
        completion_state: AiApiAuditLog::CompletionState::EMPTY,
        stop_reason: "max_tokens",
        response_tokens: 100,
      )
    end

    it "classifies non-streaming structured output before returning early" do
      response = mock_converse_response(text: '{"message":"Answer"}')
      response.stop_reason = "max_tokens"
      stub_sdk_client(response: response)
      prompt = DiscourseAi::Completions::Prompt.new("Input")
      dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)
      endpoint.perform_completion!(
        dialect,
        user,
        {
          response_format: {
            json_schema: {
              schema: {
                properties: {
                  message: {
                    type: "string",
                  },
                },
              },
            },
          },
        },
      )
      expect(AiApiAuditLog.last).to have_attributes(
        completion_state: AiApiAuditLog::CompletionState::TRUNCATED,
        stop_reason: "max_tokens",
      )
    end
  end

  it "bounds unexpected SDK stop reasons before persisting" do
    reason = "x" * 100
    response = mock_converse_response
    response.stop_reason = reason
    stub_sdk_client(response: response)
    model.to_llm.generate("Input", user: user)
    expect(AiApiAuditLog.last.stop_reason).to eq(reason.first(50))
  end

  it "classifies broken structured streaming output after finishing its buffer" do
    stub_sdk_client do |listeners|
      fire_message_start(listeners)
      fire_content_block_delta(listeners, text: "{broken")
      fire_message_stop(listeners)
      fire_metadata(listeners)
    end
    partials = []
    prompt = DiscourseAi::Completions::Prompt.new("Input")
    dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)
    params = {
      response_format: {
        json_schema: {
          schema: {
            properties: {
              message: {
                type: "string",
              },
            },
          },
        },
      },
    }
    endpoint.perform_completion!(dialect, user, params) { |partial| partials << partial }
    expect(partials.last).to be_a(DiscourseAi::Completions::StructuredOutput)
    expect(partials.last.to_s).to eq("{broken")
    expect(AiApiAuditLog.last.completion_state).to eq(AiApiAuditLog::CompletionState::COMPLETE)
  end

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
    it "sets max_tokens to the known model cap by default" do
      prompt = DiscourseAi::Completions::Prompt.new("hello")
      dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)

      expect(endpoint.default_options(dialect)[:max_tokens]).to eq(4096)
    end

    it "assumes a 64k cap for unrecognised Claude models when no limit is configured" do
      model.update!(name: "claude-sonnet-99")

      prompt = DiscourseAi::Completions::Prompt.new("hello")
      dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)

      expect(endpoint.default_options(dialect)[:max_tokens]).to eq(64_000)
    end

    it "uses the configured limit over the known cap" do
      model.update!(max_output_tokens: 2000)

      prompt = DiscourseAi::Completions::Prompt.new("hello")
      dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)

      expect(endpoint.default_options(dialect)[:max_tokens]).to eq(2000)
    end

    it "does not set max_tokens for non-Claude models" do
      model.update!(name: "amazon.nova-pro-v1:0")

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
      model.update!(max_output_tokens: 8192)
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

    it "configures xhigh effort" do
      model.provider_params["effort"] = "xhigh"

      prompt = DiscourseAi::Completions::Prompt.new("hello")
      dialect = DiscourseAi::Completions::Dialects::Converse.new(prompt, model)

      options = endpoint.default_options(dialect)
      expect(options[:output_config]).to eq({ effort: "xhigh" })
    end
  end

  it "bounds reasoning-inclusive root, child and helper requests on the same model" do
    model.update!(
      max_prompt_tokens: 200_000,
      max_output_tokens: 64_000,
      provider_params:
        model.provider_params.merge("enable_reasoning" => true, "reasoning_tokens" => 32_768),
    )
    child =
      Fabricate(
        :ai_agent,
        default_llm_id: model.id,
        max_turn_tokens: 32_000,
        thinking_effort: "high",
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      )
    parent =
      Fabricate(
        :ai_agent,
        default_llm_id: model.id,
        max_turn_tokens: 32_000,
        subagent_ids: [child.id],
      )
    Group.refresh_automatic_groups!
    execution =
      DiscourseAi::Completions::ExecutionContext.new(
        token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
      )
    state =
      DiscourseAi::Agents::SubagentExecutionState.new(
        execution_context: execution,
        root_token_budget: 32_000,
      )
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        execution_context: execution,
        subagent_execution_state: state,
      )
    calls = []
    client =
      stub_sdk_client(
        response: mock_converse_response(text: "Helper", output_tokens: 25),
      ) do |listeners|
        fire_message_start(listeners)
        fire_content_block_delta(listeners, text: "Evidence")
        fire_content_block_stop(listeners)
        fire_message_stop(listeners)
        fire_metadata(listeners, output_tokens: 35)
      end
    reservation = execution.work_budget.reserve_output(16_000)
    model
      .to_llm
      .generate(
        "Root",
        user: user,
        execution_context: execution,
        max_tokens: 16_000,
        thinking_effort: "high",
        work_generation_admitted: true,
      ) do |partial|
        next if !partial.is_a?(String) || partial.empty? || calls.present?
        runner =
          DiscourseAi::Agents::SubagentRunner.new(
            parent_agent: parent.class_instance.new,
            child_id: child.id,
            prompt: "Check the evidence",
            context: context,
            parent_llm: model.to_llm,
          )
        calls << runner.run
        calls << model.to_llm.generate(
          "Helper",
          user: user,
          execution_context: execution,
          thinking_effort: "high",
        )
      end
    expect(calls.first[:response]).to eq("Evidence")
    expect(calls.last).to eq("Helper")
    expect(client).to have_received(:converse_stream).twice do |params|
      expect(params.dig(:inference_config, :max_tokens)).to eq(16_000)
      expect(params.dig(:additional_model_request_fields, :thinking, :budget_tokens)).to eq(14_976)
    end
    expect(client).to have_received(:converse) do |params|
      expect(params.dig(:inference_config, :max_tokens)).to eq(15_965)
      expect(params.dig(:additional_model_request_fields, :thinking, :budget_tokens)).to eq(14_941)
    end
    expect(execution.work_budget.used).to eq(95)
    expect(execution.work_budget.limit).to eq(32_000)
    expect(execution.token_usage_tracker.response).to eq(95)
  ensure
    execution&.work_budget&.release_output(reservation)
  end

  it "excludes Converse maintenance from work and ordinary usage while preserving actual bills" do
    stub_sdk_client(response: mock_converse_response(input_tokens: 100, output_tokens: 35))
    execution =
      DiscourseAi::Completions::ExecutionContext.new(
        token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
        work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000, used: 250),
      )
    model.to_llm.generate(
      "Summarize history",
      user: user,
      feature_name: "context_compression",
      execution_context: execution,
    )
    expect(execution.work_budget.used).to eq(250)
    expect(execution.token_usage_tracker.total).to eq(135)
    expect(execution.token_usage_tracker.preparation_tokens).to eq(135)
    model.to_llm.generate("Answer", user: user, execution_context: execution)
    expect(execution.work_budget.used).to eq(285)
    expect(execution.token_usage_tracker.total).to eq(270)
  end

  it "settles partially emitted cancelled Converse output and actual usage" do
    cancel = DiscourseAi::Completions::CancelManager.new
    stub_sdk_client do |listeners|
      fire_message_start(listeners)
      fire_content_block_delta(listeners, text: "Partial answer")
      fire_message_stop(listeners)
    end
    execution =
      DiscourseAi::Completions::ExecutionContext.new(
        token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
        work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000),
      )
    model
      .to_llm
      .generate("Answer", user: user, execution_context: execution, cancel_manager: cancel) do
        cancel.cancel!
      end
    expect(execution.work_budget.used).to eq(model.to_llm.tokenizer.size("Partial answer"))
    expect(execution.token_usage_tracker.response).to be > 0
    expect(AiApiAuditLog.last.completion_state).to be_nil
    expect(AiApiAuditLog.last.raw_request_payload).to be_present
  end

  describe "non-streaming completion" do
    it "completes a simple prompt" do
      described_class.any_instance.stubs(:monotonic_milliseconds).returns(1_000, 1_180)
      response = mock_converse_response(text: "Test response", input_tokens: 15, output_tokens: 8)
      client = stub_sdk_client(response: response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      result = llm.generate("hello", user: user)

      expect(result).to eq("Test response")
      expect(AiApiAuditLog.last).to have_attributes(
        request_tokens: 15,
        response_tokens: 8,
        time_to_first_token_msecs: 180,
      )
    end

    it "passes thinking config for Claude models" do
      model.update!(max_output_tokens: 8192)
      response = mock_converse_response
      client = stub_sdk_client(response: response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user, thinking_effort: "low")

      expect(client).to have_received(:converse) do |params|
        expect(params.dig(:additional_model_request_fields, :thinking)).to eq(
          type: "enabled",
          budget_tokens: 4096,
        )
      end
    end

    it "uses adaptive thinking for Claude models that only support it" do
      model.update!(
        name: "global.anthropic.claude-opus-4-7-v1:0",
        provider_params:
          model.provider_params.merge("enable_reasoning" => true, "adaptive_thinking" => true),
      )
      response = mock_converse_response
      client = stub_sdk_client(response: response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user, thinking_effort: "high")

      expect(client).to have_received(:converse) do |params|
        expect(params.dig(:additional_model_request_fields, :thinking)).to eq(type: "adaptive")
        expect(params.dig(:additional_model_request_fields, :output_config)).to eq(effort: "high")
      end
    end

    it "does not pass Anthropic thinking config for non-Claude models" do
      SiteSetting.ai_llm_temperature_top_p_enabled = true
      model.update!(name: "meta.llama3-1-70b-instruct-v1:0")
      response = mock_converse_response
      client = stub_sdk_client(response: response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user, thinking_effort: "low", temperature: 0.7)

      expect(client).to have_received(:converse) do |params|
        expect(params[:additional_model_request_fields]).to be_blank
        expect(params.dig(:inference_config, :temperature)).to eq(0.7)
      end
    end

    it "translates friendly model names to Bedrock model IDs for the SDK" do
      response = mock_converse_response
      client = stub_sdk_client(response: response)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate("hello", user: user)

      expect(client).to have_received(:converse) do |params|
        expect(params[:model_id]).to eq("anthropic.claude-3-sonnet-20240229-v1:0")
        expect(params[:system]).to be_present
      end
    end

    it "translates newer friendly names and passes qualified IDs through" do
      response = mock_converse_response
      client = stub_sdk_client(response: response)
      seen_model_ids = []
      allow(client).to receive(:converse) do |params|
        seen_model_ids << params[:model_id]
        response
      end

      {
        "claude-opus-4-1" => "anthropic.claude-opus-4-1-20250805-v1:0",
        "claude-opus-4-5" => "anthropic.claude-opus-4-5-20251101-v1:0",
        "claude-sonnet-4-6" => "anthropic.claude-sonnet-4-6",
        "claude-opus-4-8" => "anthropic.claude-opus-4-8",
        "global.anthropic.claude-sonnet-4-6" => "global.anthropic.claude-sonnet-4-6",
        "amazon.nova-pro-v1:0" => "amazon.nova-pro-v1:0",
      }.each do |friendly_name, bedrock_id|
        model.update!(name: friendly_name)
        DiscourseAi::Completions::Llm.proxy("custom:#{model.id}").generate("hello", user: user)
        expect(seen_model_ids.last).to eq(bedrock_id)
      end
    end

    it "logs a placeholder when image bytes are binary" do
      model.update!(vision_enabled: true)
      raw_bytes = "\x89PNG\r\n\x1a\nbinary".b
      response = mock_converse_response
      client = stub_sdk_client(response: response)
      prompt =
        DiscourseAi::Completions::Prompt.new(
          nil,
          messages: [{ type: :user, content: ["Describe: ", { upload_id: 456 }] }],
        )

      allow(DiscourseAi::Completions::UploadEncoder).to receive(:encode).and_return(
        [{ kind: :image, mime_type: "image/png", base64: Base64.strict_encode64(raw_bytes) }],
      )

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      result = llm.generate(prompt, user: user)

      expect(result).to eq("Hello world")
      expect(AiApiAuditLog.last.raw_request_payload).to eq(
        "[converse params contained binary payload, omitted from log]",
      )
      expect(client).to have_received(:converse) do |params|
        expect(params.dig(:messages, 0, :content, 1, :image, :source, :bytes)).to eq(raw_bytes)
      end
    end
  end

  describe "streaming completion" do
    it "streams text responses" do
      described_class.any_instance.stubs(:monotonic_milliseconds).returns(1_000, 1_090, 9_999)
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
      expect(AiApiAuditLog.last).to have_attributes(
        request_tokens: 10,
        response_tokens: 3,
        time_to_first_token_msecs: 90,
      )
    end

    it "waits for non-empty structured output before recording time to first token" do
      described_class.any_instance.stubs(:monotonic_milliseconds).returns(1_000, 1_120)
      stub_sdk_client do |listeners|
        fire_message_start(listeners)
        fire_content_block_delta(listeners, text: "")
        fire_content_block_delta(listeners, text: '{"message":"Hello"}')
        fire_content_block_stop(listeners)
        fire_message_stop(listeners)
        fire_metadata(listeners)
      end

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")
      llm.generate(
        "hello",
        user: user,
        response_format: {
          json_schema: {
            schema: {
              properties: {
                message: {
                  type: "string",
                },
              },
            },
          },
        },
      ) { |_partial| }

      expect(AiApiAuditLog.last.time_to_first_token_msecs).to eq(120)
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
      expect(AiApiAuditLog.last.response_status).to be_nil
    end

    it "records SDK error response status when available" do
      client = instance_double(Aws::BedrockRuntime::Client)
      context = Seahorse::Client::RequestContext.new
      context.http_response.status_code = 429
      allow(client).to receive(:converse).and_raise(
        Aws::BedrockRuntime::Errors::ThrottlingException.new(context, "Rate exceeded"),
      )
      allow(Aws::BedrockRuntime::Client).to receive(:new).and_return(client)

      llm = DiscourseAi::Completions::Llm.proxy("custom:#{model.id}")

      expect { llm.generate("hello", user: user) }.to raise_error(
        DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
      )
      expect(AiApiAuditLog.last.response_status).to eq(429)
    end
  end
end
