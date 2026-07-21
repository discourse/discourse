# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::StreamReplyCustomToolsSession do
  fab!(:admin)
  fab!(:llm) { Fabricate(:llm_model, name: "fake_llm", provider: "fake") }
  fab!(:ai_agent) do
    agent =
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_personal_messages: true,
        max_turn_tokens: 5000,
        compression_threshold: 80,
      )
    agent.create_user!
    agent
  end

  let(:custom_tools) do
    [
      {
        name: "client_tool",
        description: "A test tool",
        parameters: [{ name: "input", description: "input value", type: "string", required: true }],
      },
    ]
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "10"
    Group.refresh_automatic_groups!
  end

  def build_session(query: "test question", resume_token: nil, tool_results: nil)
    described_class.new(
      agent: ai_agent,
      user: admin,
      topic: nil,
      query: query,
      custom_instructions: nil,
      current_user: admin,
      custom_tools: custom_tools,
      resume_token: resume_token,
      tool_results: tool_results,
    )
  end

  def collect_events(session)
    events = []
    session.run { |type, data| events << [type, data] }
    events
  end

  describe "custom tool resume" do
    it "reconstructs resumed parallel vLLM tool calls as one assistant batch" do
      vllm_model = Fabricate(:vllm_model)
      ai_agent.update!(default_llm_id: vllm_model.id)
      provider_data = { vllm: { tool_batch_id: "response-1" } }
      tool_calls =
        %w[one two].map do |input|
          DiscourseAi::Completions::ToolCall.new(
            name: "client_tool",
            parameters: {
              input: input,
            },
            id: "tool_#{input}",
            provider_data: provider_data,
          )
        end

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_calls, "Final answer after tools.", "Test title"],
      ) do |_, _, prompts|
        tool_event = collect_events(build_session).find { |type, _| type == :tool_calls }

        collect_events(
          build_session(
            resume_token: tool_event[1][:resume_token],
            tool_results: [
              { tool_call_id: "tool_one", content: "first result" },
              { tool_call_id: "tool_two", content: "second result" },
            ],
          ),
        )

        translated =
          DiscourseAi::Completions::Dialects::Vllm.new(prompts.second, vllm_model).translate
        assistant_tool_messages = translated.select { |message| message[:tool_calls] }

        expect(
          assistant_tool_messages.map { |message| message[:tool_calls].map { |call| call[:id] } },
        ).to eq([%w[tool_one tool_two]])
      end
    end
  end

  describe "token budget enforcement" do
    it "enforces budget before generate when resuming over budget" do
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "hello",
          },
          id: "tool_1",
        )

      generated_requests = []
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_call, "Final answer after budget pre-check.", "Test title"],
      ) do
        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |original, *args, **kwargs, &blk|
          prompt = args.first
          generated_requests << {
            tool_choice: prompt.tool_choice,
            last_message: prompt.messages.last.dup,
          }
          original.call(*args, **kwargs, &blk)
        end

        session = build_session
        events = collect_events(session)

        tool_event = events.find { |type, _| type == :tool_calls }
        expect(tool_event).to be_present

        resume_token = tool_event[1][:resume_token]

        # Inflate accumulated_tokens in Redis to exceed budget
        raw = Discourse.redis.get(described_class.redis_key(resume_token))
        state = JSON.parse(raw)
        state["accumulated_tokens"] = 999_999
        Discourse.redis.setex(
          described_class.redis_key(resume_token),
          described_class::RESUME_STATE_TTL_SECONDS,
          state.to_json,
        )

        # Resume with tool results — budget already exceeded before generate
        resumed_events = []
        resumed_session =
          build_session(
            resume_token: resume_token,
            tool_results: [{ tool_call_id: "tool_1", content: "tool output" }],
          )
        resumed_session.run { |type, data| resumed_events << [type, data] }

        partials = resumed_events.select { |type, _| type == :partial }.map { |_, data| data }
        expect(partials.join).to eq("Final answer after budget pre-check.")
        finalization_request =
          generated_requests.find do |request|
            request[:last_message][:content] ==
              DiscourseAi::Agents::Bot::TOKEN_BUDGET_FINAL_ANSWER_HINT
          end
        expect(finalization_request).to eq(
          tool_choice: :none,
          last_message: {
            type: :user,
            content: DiscourseAi::Agents::Bot::TOKEN_BUDGET_FINAL_ANSWER_HINT,
          },
        )

        tool_events = resumed_events.select { |type, _| type == :tool_calls }
        expect(tool_events).to be_empty
      end
    end

    it "triggers synthetic tool errors + final text when budget exhausted mid-round" do
      ai_agent.update!(max_turn_tokens: 1)

      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "test",
          },
          id: "tool_2",
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_call, "Summary after budget hit."],
      ) do
        session = build_session

        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |original, *args, **kwargs, &blk|
          result = original.call(*args, **kwargs, &blk)
          if (tracker = kwargs[:execution_context]&.token_usage_tracker)
            tracker.add_effective(request: 500, response: 500)
          end
          result
        end

        events = collect_events(session)

        partials = events.select { |type, _| type == :partial }.map { |_, data| data }
        expect(partials.join).to eq("Summary after budget hit.")

        tool_events = events.select { |type, _| type == :tool_calls }
        expect(tool_events).to be_empty
      end
    end

    it "defaults the budget to half the context window without max_turn_tokens" do
      # An agent with no max_turn_tokens uses half the LLM context window
      # (fake_llm has max_prompt_tokens 131_072 → 65_536).
      ai_agent.update!(max_turn_tokens: nil)

      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "test",
          },
          id: "tool_4",
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_call, "Summary after budget hit."],
      ) do
        session = build_session

        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |original, *args, **kwargs, &blk|
          result = original.call(*args, **kwargs, &blk)
          # 70_000 tokens exceeds the 65_536 default budget after the first call.
          if (tracker = kwargs[:execution_context]&.token_usage_tracker)
            tracker.add_effective(request: 40_000, response: 30_000)
          end
          result
        end

        events = collect_events(session)

        partials = events.select { |type, _| type == :partial }.map { |_, data| data }
        expect(partials.join).to eq("Summary after budget hit.")

        tool_events = events.select { |type, _| type == :tool_calls }
        expect(tool_events).to be_empty
      end
    end

    it "persists request and response token counters in resume state" do
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "hello",
          },
          id: "tool_3",
        )

      DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do
        session = build_session

        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |original, *args, **kwargs, &blk|
          result = original.call(*args, **kwargs, &blk)
          if (tracker = kwargs[:execution_context]&.token_usage_tracker)
            tracker.add_effective(request: 123, response: 45)
          end
          result
        end

        events = collect_events(session)
        tool_event = events.find { |type, _| type == :tool_calls }
        expect(tool_event).to be_present

        state =
          JSON.parse(Discourse.redis.get(described_class.redis_key(tool_event[1][:resume_token])))
        expect(state["accumulated_request_tokens"]).to eq(123)
        expect(state["accumulated_response_tokens"]).to eq(45)
        expect(state["accumulated_tokens"]).to eq(168)
      end
    end

    it "propagates llm errors" do
      DiscourseAi::Completions::Llm.with_prepared_responses([RuntimeError.new("boom")]) do
        session = build_session
        expect { collect_events(session) }.to raise_error(RuntimeError, "boom")
      end
    end
  end
end
