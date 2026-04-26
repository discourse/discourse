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
        execution_mode: "agentic",
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

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_call, "Final answer after budget pre-check."],
      ) do
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
