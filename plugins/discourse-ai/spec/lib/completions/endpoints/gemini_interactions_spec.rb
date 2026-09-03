# frozen_string_literal: true

require_relative "endpoint_compliance"

RSpec.describe DiscourseAi::Completions::Endpoints::GeminiInteractions do
  subject(:endpoint) { described_class.new(model) }

  fab!(:model) { Fabricate(:gemini_interactions_model, vision_enabled: true) }
  fab!(:user)

  let(:url) { "https://generativelanguage.googleapis.com/v1/interactions" }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(model) }
  let(:echo_tool) do
    {
      name: "echo",
      description: "Echo text",
      parameters: [{ name: "text", type: "string", description: "Text to echo", required: true }],
    }
  end

  before { enable_current_plugin }

  def interaction_response(steps:, usage: nil, status: "completed")
    {
      object: "interaction",
      model: model.name,
      status:,
      steps:,
      usage:
        usage ||
          {
            total_input_tokens: 10,
            total_cached_tokens: 0,
            total_output_tokens: 4,
            total_thought_tokens: 0,
            total_tool_use_tokens: 0,
            total_tokens: 14,
          },
    }
  end

  def sse_event(event_type, **fields)
    "event: #{event_type}\ndata: #{fields.merge(event_type:).to_json}\n\n"
  end

  it "registers as a separate provider with the Interactions dialect and endpoint" do
    SiteSetting.ai_llm_temperature_top_p_enabled = true

    expect(DiscourseAi::Completions::Llm.provider_names).to include("gemini_interactions")
    expect(DiscourseAi::Completions::Endpoints::Base.endpoint_for(model)).to eq(described_class)
    expect(DiscourseAi::Completions::Dialects::Dialect.dialect_for(model)).to eq(
      DiscourseAi::Completions::Dialects::GeminiInteractions,
    )
    expect(LlmModel.provider_params[:gemini_interactions].keys).to contain_exactly(
      :disable_native_tools,
      :thinking_level,
      :disable_temperature,
      :disable_top_p,
      :service_tier,
    )
    expect(LlmModel.provider_params.dig(:gemini_interactions, :thinking_level, :label)).to eq(
      "discourse_ai.llms.provider_fields.gemini_interactions_thinking_level",
    )
    expect(LlmModel.provider_params.dig(:google, :thinking_level)).not_to have_key(:label)
  end

  it "generates text using stateless interactions and records provider usage" do
    SiteSetting.ai_llm_temperature_top_p_enabled = true
    request_body = nil
    response =
      interaction_response(
        steps: [
          { type: "thought", signature: "signed-thought" },
          { type: "model_output", content: [{ type: "text", text: "Hello world" }] },
        ],
        usage: {
          total_input_tokens: 120,
          total_cached_tokens: 20,
          total_output_tokens: 7,
          total_thought_tokens: 3,
          total_tool_use_tokens: 2,
          total_tokens: 132,
        },
      )

    request =
      stub_request(:post, url).with(
        headers: {
          "Content-Type" => "application/json",
          "X-Goog-Api-Key" => "123",
        },
        body:
          proc do |body|
            request_body = JSON.parse(body, symbolize_names: true)
            true
          end,
      ).to_return(status: 200, body: response.to_json)

    result =
      llm.generate(
        DiscourseAi::Completions::Prompt.new(
          "Be concise",
          messages: [{ type: :user, content: "Say hello" }],
        ),
        user:,
        temperature: 0.4,
        top_p: 0.8,
        max_tokens: 100,
        stop_sequences: ["STOP"],
      )

    expect(result).to eq(
      [
        "Hello world",
        DiscourseAi::Completions::Thinking.new(
          message: nil,
          provider_info: {
            gemini_interactions: {
              steps: [{ type: "thought", signature: "signed-thought" }],
            },
          },
        ),
      ],
    )
    expect(request).to have_been_requested.once
    expect(request_body).to eq(
      {
        store: false,
        model: "gemini-2.5-flash",
        input: [{ type: "user_input", content: [{ type: "text", text: "Say hello" }] }],
        system_instruction: "Be concise",
        generation_config: {
          temperature: 0.4,
          top_p: 0.8,
          max_output_tokens: 100,
          stop_sequences: ["STOP"],
        },
      },
    )

    log = AiApiAuditLog.last
    expect(log.provider_id).to eq(AiApiAuditLog::Provider::Gemini)
    expect(log.request_tokens).to eq(100)
    expect(log.cache_read_tokens).to eq(20)
    expect(log.response_tokens).to eq(12)
  end

  it "maps Gemini 2.5 thinking efforts to supported Interactions API levels" do
    request_bodies = []
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_bodies << JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [{ type: "model_output", content: [{ type: "text", text: "Done" }] }],
        ).to_json,
    )

    %w[minimal low medium high].each do |thinking_effort|
      expect(llm.generate("Think", user:, thinking_effort:)).to eq("Done")
    end

    expect(request_bodies.map { |body| body.dig(:generation_config, :thinking_level) }).to eq(
      %w[low low medium high],
    )
  end

  it "maps Gemini 3.8 minimal thinking effort to low" do
    model.update!(name: "gemini-3.8-flash")
    request_body = nil
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [{ type: "model_output", content: [{ type: "text", text: "Done" }] }],
        ).to_json,
    )

    expect(llm.generate("Think", user:, thinking_effort: "minimal")).to eq("Done")
    expect(request_body.dig(:generation_config, :thinking_level)).to eq("low")
  end

  it "omits the unsupported disabled thinking override for Gemini 2.5" do
    request_body = nil
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [{ type: "model_output", content: [{ type: "text", text: "Done" }] }],
        ).to_json,
    )

    expect(llm.generate("Think", user:, thinking_effort: "none")).to eq("Done")
    expect(request_body).not_to have_key(:generation_config)
  end

  it "requests summaries when Gemini 2.5 cannot honor disabled thinking" do
    request_body = nil
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [{ type: "model_output", content: [{ type: "text", text: "Done" }] }],
        ).to_json,
    )

    expect(
      llm.generate(
        "Think",
        user:,
        thinking_effort: "none",
        output_thinking: true,
        extra_model_params: {
          include_thought_summaries: true,
        },
      ),
    ).to eq("Done")
    expect(request_body[:generation_config]).to eq(thinking_summaries: "auto")
  end

  it "maps the provider-level minimal setting to low for Gemini 2.5" do
    model.update!(provider_params: { thinking_level: "minimal" })
    request_body = nil
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [{ type: "model_output", content: [{ type: "text", text: "Done" }] }],
        ).to_json,
    )

    expect(llm.generate("Think", user:)).to eq("Done")
    expect(request_body.dig(:generation_config, :thinking_level)).to eq("low")
  end

  it "maps thinking effort to the levels supported by Flash Lite image models" do
    model.update!(name: "gemini-3.1-flash-lite-image")
    request_bodies = []
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_bodies << JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [{ type: "model_output", content: [{ type: "text", text: "Done" }] }],
        ).to_json,
    )

    %w[minimal low medium high].each do |thinking_effort|
      expect(llm.generate("Draw", user:, thinking_effort:)).to eq("Done")
    end

    expect(request_bodies.map { |body| body.dig(:generation_config, :thinking_level) }).to eq(
      %w[minimal minimal high high],
    )
  end

  it "streams text and thought summaries from fragmented SSE records" do
    model.update!(provider_params: { thinking_level: "low" })
    stream = +""
    stream << sse_event("interaction.created", interaction: { status: "in_progress" })
    stream << sse_event("step.start", index: 0, step: { type: "thought" })
    stream << sse_event(
      "step.delta",
      index: 0,
      delta: {
        type: "thought_summary",
        content: {
          text: "Checking",
        },
      },
    )
    stream << sse_event(
      "step.delta",
      index: 0,
      delta: {
        type: "thought_signature",
        signature: "sig-1",
      },
    )
    stream << sse_event("step.stop", index: 0)
    stream << sse_event("step.start", index: 1, step: { type: "model_output" })
    stream << sse_event("step.delta", index: 1, delta: { type: "text", text: "Hel" })
    stream << sse_event("step.delta", index: 1, delta: { type: "text", text: "lo" })
    stream << sse_event("step.stop", index: 1)
    stream << sse_event(
      "interaction.completed",
      interaction: {
        status: "completed",
        usage: {
          total_input_tokens: 8,
          total_cached_tokens: 0,
          total_output_tokens: 2,
          total_thought_tokens: 1,
          total_tool_use_tokens: 0,
        },
      },
    )
    stream << "event: done\ndata: [DONE]\n\n"

    request_body = nil
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(status: 200, body: stream.chars.each_slice(17).map(&:join))

    partials = []
    EndpointMock.with_chunk_array_support do
      result =
        llm.generate(
          "Hello",
          user:,
          output_thinking: true,
          extra_model_params: {
            include_thought_summaries: true,
          },
        ) { |partial| partials << partial }
      expect(result).to eq("Hello")
    end

    expect(request_body[:stream]).to eq(true)
    expect(request_body[:generation_config]).to eq(
      { thinking_level: "low", thinking_summaries: "auto" },
    )
    expect(
      partials.map do |partial|
        if partial.is_a?(DiscourseAi::Completions::Thinking)
          [partial.message, partial.partial?, partial.provider_info]
        else
          partial
        end
      end,
    ).to eq(
      [
        ["Checking", true, {}],
        ["Checking", false, {}],
        "Hel",
        "lo",
        [
          nil,
          false,
          {
            gemini_interactions: {
              steps: [{ type: "thought", summary: [{ text: "Checking" }], signature: "sig-1" }],
            },
          },
        ],
      ],
    )
    expect(AiApiAuditLog.last.response_tokens).to eq(3)
  end

  it "renders and preserves non-streamed text and image thought summaries" do
    image_data =
      Base64.strict_encode64(
        File.binread(File.expand_path("../../../fixtures/images/100x100.jpg", __dir__)),
      )
    thought_step = {
      type: "thought",
      signature: "signed-image-thought",
      summary: [
        { type: "text", text: "Visualizing" },
        { type: "image", mime_type: "image/jpeg", data: image_data },
      ],
    }
    request_body = nil
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [
            thought_step,
            { type: "model_output", content: [{ type: "text", text: "Done" }] },
          ],
        ).to_json,
    )

    result = nil
    expect do
      result =
        llm.generate(
          "Think visually",
          user:,
          output_thinking: true,
          extra_model_params: {
            include_thought_summaries: true,
          },
        )
    end.to change(Upload, :count).by(1)

    expect(request_body.dig(:generation_config, :thinking_summaries)).to eq("auto")
    expect(result.first.message).to start_with("Visualizing\n\n![image](upload://")
    expect(result.last.provider_info.dig(:gemini_interactions, :steps)).to eq([thought_step])
  end

  it "renders streamed image thought summaries and preserves their signature" do
    image_data =
      Base64.strict_encode64(
        File.binread(File.expand_path("../../../fixtures/images/100x100.jpg", __dir__)),
      )
    stream = +""
    stream << sse_event("step.start", index: 0, step: { type: "thought" })
    stream << sse_event(
      "step.delta",
      index: 0,
      delta: {
        type: "thought_summary",
        content: {
          type: "image",
          mime_type: "image/jpeg",
          data: image_data,
        },
      },
    )
    stream << sse_event(
      "step.delta",
      index: 0,
      delta: {
        type: "thought_signature",
        signature: "streamed-image-signature",
      },
    )
    stream << sse_event("step.stop", index: 0)
    stream << sse_event("step.start", index: 1, step: { type: "model_output" })
    stream << sse_event("step.delta", index: 1, delta: { type: "text", text: "Done" })
    stream << sse_event("step.stop", index: 1)
    stream << sse_event(
      "interaction.completed",
      interaction: {
        status: "completed",
        usage: {
          total_input_tokens: 1,
          total_cached_tokens: 0,
          total_output_tokens: 1,
          total_thought_tokens: 1,
          total_tool_use_tokens: 0,
        },
      },
    )
    stub_request(:post, url).to_return(status: 200, body: stream)
    partials = []

    expect do
      expect(
        llm.generate("Think visually", user:, output_thinking: true) do |partial|
          partials << partial
        end,
      ).to eq("Done")
    end.to change(Upload, :count).by(1)

    visible_thinking =
      partials.find do |partial|
        partial.is_a?(DiscourseAi::Completions::Thinking) && partial.message.present?
      end
    context_thinking =
      partials.find do |partial|
        partial.is_a?(DiscourseAi::Completions::Thinking) && partial.provider_info.present?
      end
    expect(visible_thinking.message).to start_with("![image](upload://")
    expect(context_thinking.provider_info.dig(:gemini_interactions, :steps, 0, :signature)).to eq(
      "streamed-image-signature",
    )
  end

  it "preserves signature-only thought steps without rendering a summary" do
    thought_step = { type: "thought", signature: "signature-only" }
    stub_request(:post, url).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [
            thought_step,
            { type: "model_output", content: [{ type: "text", text: "Done" }] },
          ],
        ).to_json,
    )

    result = llm.generate("Think", user:, output_thinking: true)

    expect(result).to eq(
      [
        "Done",
        DiscourseAi::Completions::Thinking.new(
          message: nil,
          provider_info: {
            gemini_interactions: {
              steps: [thought_step],
            },
          },
        ),
      ],
    )
  end

  it "replays signed thought steps when summaries are not returned to the caller" do
    prompt =
      DiscourseAi::Completions::Prompt.new(messages: [{ type: :user, content: "Remember PLUM" }])
    thought_step = { type: "thought", signature: "signed-history" }
    second_request = nil

    stub_request(:post, url).with(
      body:
        proc do |body|
          parsed = JSON.parse(body, symbolize_names: true)
          second_request = parsed if parsed[:input].length > 1
          true
        end,
    ).to_return(
      {
        status: 200,
        body:
          interaction_response(
            steps: [
              thought_step,
              { type: "model_output", content: [{ type: "text", text: "OK" }] },
            ],
          ).to_json,
      },
      {
        status: 200,
        body:
          interaction_response(
            steps: [{ type: "model_output", content: [{ type: "text", text: "PLUM" }] }],
          ).to_json,
      },
    )

    first = llm.generate(prompt, user:)
    prompt.push_model_response(first)
    prompt.push(type: :user, content: "Repeat it")
    model.update!(name: "gemini-3.6-flash")
    expect(llm.generate(prompt, user:)).to eq("PLUM")

    expect(second_request[:model]).to eq("gemini-3.6-flash")
    expect(second_request[:input]).to eq(
      [
        { type: "user_input", content: [{ type: "text", text: "Remember PLUM" }] },
        thought_step,
        { type: "model_output", content: [{ type: "text", text: "OK" }] },
        { type: "user_input", content: [{ type: "text", text: "Repeat it" }] },
      ],
    )
  end

  it "replays signed built-in tool steps when thinking output is hidden" do
    prompt = DiscourseAi::Completions::Prompt.new(messages: [{ type: :user, content: "Search" }])
    search_call = {
      type: "google_search_call",
      id: "search-1",
      arguments: {
        queries: ["Discourse"],
      },
      signature: "call-signature",
    }
    search_result = {
      type: "google_search_result",
      call_id: "search-1",
      result: {
        snippets: [],
      },
      signature: "result-signature",
    }
    second_request = nil
    stub_request(:post, url).with(
      body:
        proc do |body|
          parsed = JSON.parse(body, symbolize_names: true)
          second_request = parsed if parsed[:input].length > 1
          true
        end,
    ).to_return(
      {
        status: 200,
        body:
          interaction_response(
            steps: [
              search_call,
              search_result,
              { type: "model_output", content: [{ type: "text", text: "Found" }] },
            ],
          ).to_json,
      },
      {
        status: 200,
        body:
          interaction_response(
            steps: [{ type: "model_output", content: [{ type: "text", text: "Done" }] }],
          ).to_json,
      },
    )

    first = llm.generate(prompt, user:)
    prompt.push_model_response(first)
    prompt.push(type: :user, content: "Continue")
    expect(llm.generate(prompt, user:)).to eq("Done")

    expect(second_request[:input]).to eq(
      [
        { type: "user_input", content: [{ type: "text", text: "Search" }] },
        search_call,
        search_result,
        { type: "model_output", content: [{ type: "text", text: "Found" }] },
        { type: "user_input", content: [{ type: "text", text: "Continue" }] },
      ],
    )
  end

  it "returns function calls and replays exact steps with the function result" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "Use tools",
        messages: [{ type: :user, content: "Echo hi" }],
        tools: [echo_tool],
        tool_choice: "echo",
      )
    thought_step = { type: "thought", signature: "tool-thought" }
    call_step = { type: "function_call", id: "call-123", name: "echo", arguments: { text: "hi" } }
    first_body = nil
    second_body = nil

    stub_request(:post, url).with(
      body:
        proc do |body|
          parsed = JSON.parse(body, symbolize_names: true)
          if first_body
            second_body = parsed
          else
            first_body = parsed
          end
          true
        end,
    ).to_return(
      {
        status: 200,
        body:
          interaction_response(status: "requires_action", steps: [thought_step, call_step]).to_json,
      },
      {
        status: 200,
        body:
          interaction_response(
            steps: [{ type: "model_output", content: [{ type: "text", text: "hi" }] }],
          ).to_json,
      },
    )

    tool_call = llm.generate(prompt, user:)
    expect(tool_call).to eq(
      DiscourseAi::Completions::ToolCall.new(
        id: "call-123",
        name: "echo",
        parameters: {
          text: "hi",
        },
        provider_data: {
          gemini_interactions: {
            steps: [thought_step, call_step],
          },
        },
      ),
    )

    prompt.push_model_response(tool_call)
    prompt.push(type: :tool, id: tool_call.id, name: tool_call.name, content: '{"value":"hi"}')
    prompt.tool_choice = :none
    expect(llm.generate(prompt, user:)).to eq("hi")

    expect(first_body[:tools]).to eq(
      [
        {
          type: "function",
          name: "echo",
          description: "Echo text",
          parameters: {
            type: "object",
            properties: {
              text: {
                type: "string",
                description: "Text to echo",
              },
            },
            required: ["text"],
          },
        },
      ],
    )
    expect(first_body.dig(:generation_config, :tool_choice)).to eq(
      { allowed_tools: { mode: "any", tools: ["echo"] } },
    )
    expect(second_body[:input]).to eq(
      [
        { type: "user_input", content: [{ type: "text", text: "Echo hi" }] },
        thought_step,
        call_step,
        { type: "function_result", call_id: "call-123", name: "echo", result: '{"value":"hi"}' },
      ],
    )
    expect(second_body.dig(:generation_config, :tool_choice)).to eq("none")
  end

  it "streams partial and completed function calls" do
    stream = +""
    stream << sse_event(
      "step.start",
      index: 0,
      step: {
        type: "function_call",
        id: "call-1",
        name: "echo",
        arguments: '{"text":"h',
      },
    )
    stream << sse_event(
      "step.delta",
      index: 0,
      delta: {
        type: "arguments",
        partial_arguments: "el",
      },
    )
    stream << sse_event(
      "step.delta",
      index: 0,
      delta: {
        type: "arguments",
        partial_arguments: 'lo"}',
      },
    )
    stream << sse_event("step.stop", index: 0)
    stream << sse_event(
      "interaction.completed",
      interaction: {
        usage: {
          total_input_tokens: 1,
          total_cached_tokens: 0,
          total_output_tokens: 1,
          total_thought_tokens: 0,
          total_tool_use_tokens: 0,
        },
      },
    )

    stub_request(:post, url).to_return(status: 200, body: stream)
    prompt = DiscourseAi::Completions::Prompt.new("Use tools", tools: [echo_tool])
    partials = []
    progress = []

    llm.generate(prompt, user:, partial_tool_calls: true) do |partial|
      partials << partial.dup
      progress << partial.parameters[:text].dup if partial.partial?
    end

    expect(partials.last).to eq(
      DiscourseAi::Completions::ToolCall.new(
        id: "call-1",
        name: "echo",
        parameters: {
          text: "hello",
        },
        provider_data: {
          gemini_interactions: {
            steps: [
              { type: "function_call", id: "call-1", name: "echo", arguments: { text: "hello" } },
            ],
          },
        },
      ),
    )
    expect(progress).to eq(%w[h hel hello])
  end

  it "delivers generated images before raising a later error from the same SSE chunk" do
    image_path = File.expand_path("../../../fixtures/images/100x100.jpg", __dir__)
    image_data = Base64.strict_encode64(File.binread(image_path))
    stream = +""
    stream << sse_event("step.start", index: 0, step: { type: "model_output" })
    stream << sse_event(
      "step.delta",
      index: 0,
      delta: {
        type: "image",
        mime_type: "image/jpeg",
        data: image_data,
      },
    )
    stream << sse_event("step.stop", index: 0)
    stream << sse_event("error", error: { code: "invalid_request", message: "Later failure" })
    stub_request(:post, url).to_return(status: 200, body: [stream])
    partials = []

    expect do
      expect do
        EndpointMock.with_chunk_array_support do
          llm.generate("Draw", user:) { |partial| partials << partial }
        end
      end.to raise_error(
        DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        "Later failure",
      )
    end.to change(Upload, :count).by(1)

    expect(partials.grep(String)).to contain_exactly(a_string_matching(%r{!\[image\]\(upload://}))
  end

  it "preserves streamed native code steps and shows the executed code" do
    code_call = {
      type: "code_execution_call",
      id: "code-1",
      signature: "code-signature",
      arguments: {
        language: "python",
        code: "print(42)",
      },
    }
    code_result = {
      type: "code_execution_result",
      call_id: "code-1",
      signature: "result-signature",
      result: "42\n",
      is_error: false,
    }
    chunks = [
      sse_event("step.start", index: 0, step: code_call.slice(:type, :id, :signature)),
      sse_event("step.delta", index: 0, delta: code_call.slice(:type, :arguments)),
      sse_event("step.stop", index: 0),
      sse_event("step.start", index: 1, step: code_result.slice(:type, :call_id, :signature)),
      sse_event("step.delta", index: 1, delta: code_result.slice(:type, :result, :is_error)),
      sse_event("step.stop", index: 1),
      sse_event("step.start", index: 2, step: { type: "model_output" }),
      sse_event("step.delta", index: 2, delta: { type: "text", text: "42" }),
      sse_event("step.stop", index: 2),
      sse_event(
        "interaction.completed",
        interaction: {
          status: "completed",
          usage: {
            total_input_tokens: 4,
            total_cached_tokens: 0,
            total_output_tokens: 1,
            total_thought_tokens: 0,
            total_tool_use_tokens: 1,
          },
        },
      ),
    ]
    stub_request(:post, url).to_return(status: 200, body: chunks)
    partials = []

    EndpointMock.with_chunk_array_support do
      expect(
        llm.generate("Calculate", user:, output_thinking: true) { |partial| partials << partial },
      ).to eq("42")
    end

    code_thinking =
      partials.find do |partial|
        partial.is_a?(DiscourseAi::Completions::Thinking) && partial.message.present?
      end
    expect(code_thinking.message).to eq("Code execution:\n\n```python\nprint(42)\n```")

    replay_context =
      partials.find do |partial|
        partial.is_a?(DiscourseAi::Completions::Thinking) && partial.provider_info.present?
      end
    expect(replay_context.provider_info).to eq(
      gemini_interactions: {
        steps: [code_call, code_result],
      },
    )
  end

  it "supports native search and URL context while preserving their steps" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "Research",
        messages: [{ type: :user, content: "Find the docs" }],
        native_tools: %w[web_search web_fetch],
      )
    thought_step = { type: "thought", signature: "search-thought" }
    search_call = {
      type: "google_search_call",
      id: "search-1",
      arguments: {
        queries: ["Gemini Interactions"],
      },
      signature: "search-signature",
    }
    search_result = {
      type: "google_search_result",
      call_id: "search-1",
      result: [{ title: "Docs", url: "https://ai.google.dev" }],
      signature: "result-signature",
    }
    output_step = {
      type: "model_output",
      content: [
        {
          type: "text",
          text: "Found it",
          annotations: [{ type: "url_citation", url: "https://ai.google.dev" }],
        },
      ],
    }

    stub_request(:post, url).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [thought_step, search_call, search_result, output_step],
        ).to_json,
    )
    result = llm.generate(prompt, user:, output_thinking: true)

    expect(result.first).to eq(
      DiscourseAi::Completions::Thinking.new(
        message: "Web search: Gemini Interactions",
        partial: false,
      ),
    )
    expect(result.second).to eq("Found it")
    expect(result.last.provider_info).to eq(
      gemini_interactions: {
        steps: [thought_step, search_call, search_result],
      },
    )

    prompt.push_model_response(result)
    prompt.push(type: :user, content: "Summarize that")
    translated = DiscourseAi::Completions::Dialects::GeminiInteractions.new(prompt, model).translate
    expect(translated[:input]).to eq(
      [
        { type: "user_input", content: [{ type: "text", text: "Find the docs" }] },
        thought_step,
        search_call,
        search_result,
        output_step.except(:content).merge(content: [{ type: "text", text: "Found it" }]),
        { type: "user_input", content: [{ type: "text", text: "Summarize that" }] },
      ],
    )

    request = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)
    expect(request.dig("generation_config", "tool_choice")).to be_nil
    expect(request["tools"]).to contain_exactly(
      { "type" => "google_search" },
      { "type" => "url_context" },
    )
  end

  it "supports native Maps and code execution with Maps attribution" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "Plan accurately",
        messages: [{ type: :user, content: "Find a cafe and calculate the walking time" }],
        native_tools: %w[google_maps code_execution],
      )
    code_call = {
      type: "code_execution_call",
      id: "code-1",
      arguments: {
        language: "python",
        code: "print(1200 / 80)",
      },
      signature: "code-signature",
    }
    code_result = {
      type: "code_execution_result",
      call_id: "code-1",
      result: "15.0",
      signature: "code-result-signature",
    }
    maps_call = {
      type: "google_maps_call",
      id: "maps-1",
      arguments: {
        queries: ["coffee near Central Station"],
      },
      signature: "maps-signature",
    }
    maps_result = {
      type: "google_maps_result",
      call_id: "maps-1",
      result: {
        places: [{ name: "Central Cafe", url: "https://maps.google.com/example" }],
      },
      signature: "maps-result-signature",
    }
    output_step = {
      type: "model_output",
      content: [
        {
          type: "text",
          text: "Central Cafe is a 15-minute walk away.",
          annotations: [
            {
              type: "place_citation",
              name: "Central [Cafe]",
              url: "https://maps.google.com/example",
            },
          ],
        },
      ],
    }

    stub_request(:post, url).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [code_call, code_result, maps_call, maps_result, output_step],
        ).to_json,
    )

    result = llm.generate(prompt, user:, output_thinking: true)

    expect(result).to eq(
      [
        DiscourseAi::Completions::Thinking.new(
          message: "Code execution:\n\n```python\nprint(1200 / 80)\n```",
          partial: false,
        ),
        DiscourseAi::Completions::Thinking.new(message: "Google Maps search", partial: false),
        "Central Cafe is a 15-minute walk away.\n\nGoogle Maps: [Central \\[Cafe\\]](https://maps.google.com/example)",
        DiscourseAi::Completions::Thinking.new(
          message: nil,
          partial: false,
          provider_info: {
            gemini_interactions: {
              steps: [code_call, code_result, maps_call, maps_result],
            },
          },
        ),
      ],
    )

    request = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)
    expect(request["tools"]).to contain_exactly(
      { "type" => "google_maps" },
      { "type" => "code_execution" },
    )
  end

  it "emits Google Maps attribution when streaming annotations arrive after text" do
    stream = +""
    stream << sse_event("step.start", index: 0, step: { type: "model_output" })
    stream << sse_event("step.delta", index: 0, delta: { type: "text", text: "Try Central Cafe" })
    stream << sse_event(
      "step.delta",
      index: 0,
      delta: {
        type: "text",
        text: "",
        annotations: [
          { type: "place_citation", name: "Central Cafe", url: "https://maps.google.com/example" },
        ],
      },
    )
    stream << sse_event("step.stop", index: 0)
    stream << sse_event(
      "interaction.completed",
      interaction: {
        status: "completed",
        usage: {
          total_input_tokens: 4,
          total_cached_tokens: 0,
          total_output_tokens: 3,
          total_thought_tokens: 0,
          total_tool_use_tokens: 0,
        },
      },
    )

    stub_request(:post, url).to_return(status: 200, body: stream)
    partials = []

    result = llm.generate("Find a cafe", user:) { |partial| partials << partial }

    expect(result).to eq(
      "Try Central Cafe\n\nGoogle Maps: [Central Cafe](https://maps.google.com/example)",
    )
    expect(partials).to eq(
      ["Try Central Cafe", "\n\nGoogle Maps: [Central Cafe](https://maps.google.com/example)"],
    )
  end

  it "uses validated tool choice when custom and server-side tools are combined" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "Use tools",
        messages: [{ type: :user, content: "Research and echo" }],
        tools: [echo_tool],
        native_tools: [DiscourseAi::Completions::NativeTools::WEB_SEARCH],
      )
    request_body = nil
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [{ type: "model_output", content: [{ type: "text", text: "Done" }] }],
        ).to_json,
    )

    expect(llm.generate(prompt, user:)).to eq("Done")
    expect(request_body.dig(:generation_config, :tool_choice)).to eq("validated")
  end

  it "raises completion failures returned inside successful HTTP responses and streams" do
    stub_request(:post, url).to_return(
      { status: 200, body: { status: "failed", error: { message: "Unary failure" } }.to_json },
      { status: 200, body: sse_event("error", error: { code: 13, message: "Stream failure" }) },
      {
        status: 200,
        body:
          sse_event(
            "interaction.status_update",
            status: "failed",
            error: {
              message: "Status failure",
            },
          ),
      },
    )

    expect { llm.generate("Fail", user:) }.to raise_error(
      DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
      "Unary failure",
    )
    expect { llm.generate("Fail", user:) { |_| } }.to raise_error(
      DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
      "Stream failure",
    )
    expect { llm.generate("Fail", user:) { |_| } }.to raise_error(
      DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
      "Status failure",
    )
  end

  it "supports JSON schema structured output without dropping schema keywords" do
    schema = {
      type: "json_schema",
      json_schema: {
        name: "reply",
        schema: {
          type: "object",
          properties: {
            answer: {
              type: "string",
            },
          },
          required: ["answer"],
          additionalProperties: false,
        },
      },
    }
    request_body = nil
    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [{ type: "model_output", content: [{ type: "text", text: '{"answer":"yes"}' }] }],
        ).to_json,
    )

    result = llm.generate("Answer", user:, response_format: schema)

    expect(result.read_buffered_property(:answer)).to eq("yes")
    expect(request_body[:response_format]).to eq(
      { type: "text", mime_type: "application/json", schema: schema.dig(:json_schema, :schema) },
    )
  end

  it "encodes image and PDF inputs as typed content" do
    SiteSetting.authorized_extensions = "*"
    image_file = File.open(File.expand_path("../../../fixtures/images/100x100.jpg", __dir__))
    image_upload = UploadCreator.new(image_file, "image.jpg").create_for(Discourse.system_user.id)
    pdf_file = Tempfile.new(%w[interactions .pdf])
    pdf_file.binmode
    pdf_file.write("%PDF-1.4\n%%EOF")
    pdf_file.rewind
    pdf_upload = UploadCreator.new(pdf_file, "document.pdf").create_for(Discourse.system_user.id)
    model.update!(allowed_attachment_types: %w[pdf])
    request_body = nil

    prompt =
      DiscourseAi::Completions::Prompt.new(
        "Inspect files",
        messages: [
          {
            type: :user,
            content: [
              "Describe these",
              { upload_id: image_upload.id },
              { upload_id: pdf_upload.id },
            ],
          },
        ],
      )
    encoded = prompt.encoded_uploads(prompt.messages.last, allow_documents: true)

    stub_request(:post, url).with(
      body:
        proc do |body|
          request_body = JSON.parse(body, symbolize_names: true)
          true
        end,
    ).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [{ type: "model_output", content: [{ type: "text", text: "Done" }] }],
        ).to_json,
    )

    expect(llm.generate(prompt, user:)).to eq("Done")
    expect(request_body[:input]).to eq(
      [
        {
          type: "user_input",
          content: [
            { type: "text", text: "Describe these" },
            { type: "image", mime_type: "image/jpeg", data: encoded[0][:base64] },
            { type: "document", mime_type: "application/pdf", data: encoded[1][:base64] },
          ],
        },
      ],
    )
  ensure
    pdf_file&.close!
  end

  it "turns generated image content into a Discourse upload" do
    image_path = File.expand_path("../../../fixtures/images/100x100.jpg", __dir__)
    image_data = Base64.strict_encode64(File.binread(image_path))
    stub_request(:post, url).to_return(
      status: 200,
      body:
        interaction_response(
          steps: [
            {
              type: "model_output",
              content: [{ type: "image", mime_type: "image/jpeg", data: image_data }],
            },
          ],
        ).to_json,
    )

    expect { expect(llm.generate("Draw", user:)).to match(%r{!\[image\]\(upload://}) }.to change(
      Upload,
      :count,
    ).by(1)
  end
end
