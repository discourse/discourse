# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::SubagentRunner do
  fab!(:user)
  fab!(:model, :fake_model)
  fab!(:child) do
    Fabricate(
      :ai_agent,
      name: "Fact checker",
      description: "Checks one factual claim",
      system_prompt: "Check the supplied claim and report the evidence.",
      default_llm_id: model.id,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )
  end
  fab!(:parent) do
    Fabricate(
      :ai_agent,
      name: "Lead fact checker",
      description: "Delegates individual claims",
      system_prompt: "Delegate claims and synthesize the results.",
      default_llm_id: model.id,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      subagent_ids: [child.id],
    )
  end

  before do
    enable_current_plugin
    Group.refresh_automatic_groups!
  end

  after { AiAgent.agent_cache.flush! }

  it "exposes one strict server-owned tool only when delegation is usable" do
    agent = parent.class_instance.new
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [{ type: :user, content: "Check a claim" }],
        execution_context:
          DiscourseAi::Completions::ExecutionContext.new(
            token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
          ),
      )
    context.subagent_execution_state =
      DiscourseAi::Agents::SubagentExecutionState.new(
        execution_context: context.execution_context,
        root_token_budget: 10_000,
      )

    tool_class = agent.runtime_tools(context: context).find { |tool| tool.name == "spawn_agent" }
    schema = tool_class.signature[:json_schema]

    expect(schema).to include(
      type: "object",
      required: %w[agent_id prompt],
      additionalProperties: false,
    )
    expect(schema.dig(:properties, :agent_id, :enum)).to eq([child.id])
    expect(schema.dig(:properties, :prompt, :maxLength)).to eq(20_000)

    context.server_owned_tools = false
    expect(agent.runtime_tools(context: context).map(&:name)).not_to include("spawn_agent")

    context.server_owned_tools = true
    context.subagent_depth = 2
    expect(agent.runtime_tools(context: context).map(&:name)).not_to include("spawn_agent")
  end

  it "requests a final answer when the shared spawn budget is exhausted" do
    parent.update!(tools: [["Search", nil, false]])
    spawn_calls =
      Array.new(DiscourseAi::Agents::SubagentExecutionState::MAX_SPAWN_CALLS) do |index|
        DiscourseAi::Completions::ToolCall.new(
          id: "spawn-#{index}",
          name: "spawn_agent",
          parameters: {
            agent_id: child.id,
            prompt: "Check claim #{index}",
          },
        )
      end
    responses =
      spawn_calls.each_with_index.flat_map { |call, index| [call, "Child result #{index}"] }
    responses << "Final answer"

    DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_endpoint, _llm, prompts|
      bot = DiscourseAi::Agents::Bot.as(user, agent: parent.class_instance.new, model: model)
      context =
        DiscourseAi::Agents::BotContext.new(
          user: user,
          messages: [{ type: :user, content: "Check several claims" }],
        )

      raw_context = bot.reply(context)

      expect(raw_context.last.first).to eq("Final answer")
      expect(prompts.length).to eq(responses.length)
      expect(prompts.last.tool_choice).to eq(:none)
      expect(prompts.last.messages.last).to eq(
        type: :user,
        content: DiscourseAi::Agents::Bot::TOOL_INVOCATION_BUDGET_FINAL_ANSWER_HINT,
      )
    end
  end

  it "runs the child with an isolated prompt and returns its result to the parent" do
    spawn_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "spawn-1",
        name: "spawn_agent",
        parameters: {
          agent_id: child.id,
          prompt: "Check whether the Moon orbits Earth.",
        },
      )
    updates = []

    DiscourseAi::Completions::Llm.with_prepared_responses(
      [spawn_call, "The Moon orbits Earth.", "The claim is verified."],
    ) do |_endpoint, _llm, prompts, prompt_options|
      bot = DiscourseAi::Agents::Bot.as(user, agent: parent.class_instance.new, model: model)
      context =
        DiscourseAi::Agents::BotContext.new(
          user: user,
          messages: [{ type: :user, content: "Verify the Moon claim" }],
          skip_show_thinking: false,
          feature_context: {
            "source" => "spec",
          },
        )

      bot.reply(context) { |content, raw, type| updates << [content, raw, type] }

      expect(prompts[1].messages).to contain_exactly(
        { type: :system, content: child.system_prompt },
        { type: :user, content: "Check whether the Moon orbits Earth." },
      )
      expect(prompts.last.messages.last[:content]).to include("The Moon orbits Earth.")
      expect(prompt_options[1][:feature_context]).to include(
        "subagent_parent_agent_id" => parent.id,
        "subagent_agent_id" => child.id,
        "subagent_depth" => 1,
      )
      expect(prompt_options[1][:feature_context]).not_to have_key("source")
    end

    thinking_updates = updates.select { |update| update[2] == :thinking }.flatten.compact.join
    expect(thinking_updates).to include("Consulting Fact checker")
    expect(thinking_updates).to include("Check whether the Moon orbits Earth.")
    expect(thinking_updates).not_to include("The Moon orbits Earth.")
    expect(updates.none? { |update| update[2] == :custom_raw }).to eq(true)
  end

  it "revalidates the persisted allowlist before starting a child" do
    tool_class = DiscourseAi::Agents::Tools::SpawnAgent.class_instance(parent.id, [child])
    execution_context =
      DiscourseAi::Completions::ExecutionContext.new(
        token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
      )
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [],
        execution_context: execution_context,
        subagent_execution_state:
          DiscourseAi::Agents::SubagentExecutionState.new(
            execution_context: execution_context,
            root_token_budget: 10_000,
          ),
      )
    parent.update!(subagent_ids: [])
    tool =
      tool_class.new(
        { agent_id: child.id, prompt: "Check this" },
        bot_user: user,
        llm: DiscourseAi::Completions::Llm.proxy(model),
        context: context,
        agent: parent.class_instance.new,
      )

    result = tool.invoke

    expect(result).to include(status: "error")
    expect(result[:error]).to eq(I18n.t("discourse_ai.ai_bot.subagent_errors.agent_not_allowed"))
    expect(tool.summary).to eq(I18n.t("discourse_ai.ai_bot.spawn_agent.summary", agent: "subagent"))
  end

  it "fails closed for disabled, inaccessible, and deleted children" do
    execution_context =
      DiscourseAi::Completions::ExecutionContext.new(
        token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
      )
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [],
        execution_context: execution_context,
        subagent_execution_state:
          DiscourseAi::Agents::SubagentExecutionState.new(
            execution_context: execution_context,
            root_token_budget: 10_000,
          ),
      )
    parent_agent = parent.class_instance.new

    child.update!(enabled: false)
    disabled_result =
      described_class.new(
        parent_agent: parent_agent,
        child_id: child.id,
        prompt: "Check this",
        context: context,
        parent_llm: DiscourseAi::Completions::Llm.proxy(model),
      ).run
    expect(disabled_result[:error]).to eq(
      I18n.t("discourse_ai.ai_bot.subagent_errors.unavailable_agent"),
    )

    child.update!(enabled: true, allowed_group_ids: [Group::AUTO_GROUPS[:admins]])
    inaccessible_result =
      described_class.new(
        parent_agent: parent_agent,
        child_id: child.id,
        prompt: "Check this",
        context: context,
        parent_llm: DiscourseAi::Completions::Llm.proxy(model),
      ).run
    expect(inaccessible_result[:error]).to eq(
      I18n.t("discourse_ai.ai_bot.subagent_errors.unavailable_agent"),
    )

    child.destroy!
    deleted_result =
      described_class.new(
        parent_agent: parent_agent,
        child_id: child.id,
        prompt: "Check this",
        context: context,
        parent_llm: DiscourseAi::Completions::Llm.proxy(model),
      ).run
    expect(deleted_result[:error]).to eq(
      I18n.t("discourse_ai.ai_bot.subagent_errors.agent_not_allowed"),
    )
  end

  it "returns only the child's final answer after child tool calls" do
    child.update!(tools: [["Time", nil, false]])
    execution_context =
      DiscourseAi::Completions::ExecutionContext.new(
        token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
      )
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [],
        execution_context: execution_context,
        subagent_execution_state:
          DiscourseAi::Agents::SubagentExecutionState.new(
            execution_context: execution_context,
            root_token_budget: 10_000,
          ),
      )
    time_call = DiscourseAi::Completions::ToolCall.new(id: "time-1", name: "time", parameters: {})

    result = nil
    DiscourseAi::Completions::Llm.with_prepared_responses(
      [["Starting child work", time_call], "Final child answer"],
    ) do
      result =
        described_class.new(
          parent_agent: parent.class_instance.new,
          child_id: child.id,
          prompt: "Check this",
          context: context,
          parent_llm: DiscourseAi::Completions::Llm.proxy(model),
        ).run
    end

    expect(result).to include(status: "ok", response: "Final child answer")
  end

  it "classifies cancellation during the child completion" do
    cancel_manager = DiscourseAi::Completions::CancelManager.new
    execution_context =
      DiscourseAi::Completions::ExecutionContext.new(
        token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
      )
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [],
        cancel_manager: cancel_manager,
        execution_context: execution_context,
        subagent_execution_state:
          DiscourseAi::Agents::SubagentExecutionState.new(
            execution_context: execution_context,
            root_token_budget: 10_000,
          ),
      )
    allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(:generate) do
      cancel_manager.cancel!
      raise IOError, "cancelled request"
    end

    result =
      described_class.new(
        parent_agent: parent.class_instance.new,
        child_id: child.id,
        prompt: "Check this",
        context: context,
        parent_llm: DiscourseAi::Completions::Llm.proxy(model),
      ).run

    expect(result[:error]).to eq(I18n.t("discourse_ai.ai_bot.subagent_errors.cancelled"))
  end

  it "truncates oversized child results with the parent tokenizer" do
    execution_context =
      DiscourseAi::Completions::ExecutionContext.new(
        token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
      )
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [],
        execution_context: execution_context,
        subagent_execution_state:
          DiscourseAi::Agents::SubagentExecutionState.new(
            execution_context: execution_context,
            root_token_budget: 40_000,
          ),
      )
    parent_llm = DiscourseAi::Completions::Llm.proxy(model)
    tokenizer = mock
    tokenizer.expects(:size).with("Oversized response").returns(30_001)
    tokenizer
      .expects(:truncate)
      .with(
        "Oversized response",
        described_class::MAX_RESULT_TOKENS,
        strict: SiteSetting.ai_strict_token_counting,
      )
      .returns("Bounded response")
    parent_llm.stubs(:tokenizer).returns(tokenizer)

    result = nil
    DiscourseAi::Completions::Llm.with_prepared_responses(["Oversized response"]) do
      result =
        described_class.new(
          parent_agent: parent.class_instance.new,
          child_id: child.id,
          prompt: "Check this",
          context: context,
          parent_llm: parent_llm,
        ).run
    end

    expect(result).to include(status: "ok", response: "Bounded response", truncated: true)
  end

  it "runs approval-capable tools when the child does not require approval" do
    admin = Fabricate(:admin)
    topic = Fabricate(:topic)
    child.update!(tools: [["CloseTopic", nil, false]], require_approval: false)
    spawn_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "spawn-autonomous",
        name: "spawn_agent",
        parameters: {
          agent_id: child.id,
          prompt: "Close the topic",
        },
      )
    close_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "close-autonomous",
        name: "close_topic",
        parameters: {
          topic_id: topic.id,
          closed: true,
          reason: "Requested",
        },
      )

    DiscourseAi::Completions::Llm.with_prepared_responses(
      [spawn_call, close_call, "Closed.", "The child closed it."],
    ) do
      bot = DiscourseAi::Agents::Bot.as(admin, agent: parent.class_instance.new, model: model)
      context =
        DiscourseAi::Agents::BotContext.new(
          user: admin,
          messages: [{ type: :user, content: "Close it" }],
        )

      bot.reply(context)
    end

    expect(topic.reload).to be_closed
    expect(ReviewableAiToolAction.count).to eq(0)
  end

  it "blocks tools configured to require approval in delegated runs" do
    topic = Fabricate(:topic)
    child.update!(tools: [["CloseTopic", nil, false]], require_approval: true)
    spawn_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "spawn-approval",
        name: "spawn_agent",
        parameters: {
          agent_id: child.id,
          prompt: "Close the topic",
        },
      )
    close_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "close-1",
        name: "close_topic",
        parameters: {
          topic_id: topic.id,
          closed: true,
          reason: "Requested",
        },
      )

    DiscourseAi::Completions::Llm.with_prepared_responses(
      [spawn_call, close_call, "Approval is unavailable.", "The child could not close it."],
    ) do |_endpoint, _llm, prompts|
      bot = DiscourseAi::Agents::Bot.as(user, agent: parent.class_instance.new, model: model)
      context =
        DiscourseAi::Agents::BotContext.new(
          user: user,
          messages: [{ type: :user, content: "Close it" }],
        )

      bot.reply(context)

      child_tool_result = prompts[2].messages.find { |message| message[:type] == :tool }
      expect(child_tool_result[:content]).to include(
        I18n.t("discourse_ai.ai_bot.subagent_errors.approval_unavailable"),
      )
    end

    expect(ReviewableAiToolAction.count).to eq(0)
  end

  it "rejects invalid prompts and exhausted calls" do
    execution_context =
      DiscourseAi::Completions::ExecutionContext.new(
        token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
      )
    state =
      DiscourseAi::Agents::SubagentExecutionState.new(
        execution_context: execution_context,
        root_token_budget: 10_000,
      )
    context =
      DiscourseAi::Agents::BotContext.new(
        user: user,
        messages: [],
        execution_context: execution_context,
        subagent_execution_state: state,
      )

    result =
      DiscourseAi::Agents::SubagentRunner.new(
        parent_agent: parent.class_instance.new,
        child_id: child.id,
        prompt: "x" * 20_001,
        context: context,
        parent_llm: DiscourseAi::Completions::Llm.proxy(model),
      ).run
    expect(result[:error]).to eq(I18n.t("discourse_ai.ai_bot.subagent_errors.prompt_too_long"))

    context.subagent_depth = 2
    depth_result =
      described_class.new(
        parent_agent: parent.class_instance.new,
        child_id: child.id,
        prompt: "Check this",
        context: context,
        parent_llm: DiscourseAi::Completions::Llm.proxy(model),
      ).run
    expect(depth_result[:error]).to eq(I18n.t("discourse_ai.ai_bot.subagent_errors.depth_limit"))
    context.subagent_depth = 0

    5.times { expect(state.reserve_spawn).to eq(true) }
    runner =
      DiscourseAi::Agents::SubagentRunner.new(
        parent_agent: parent.class_instance.new,
        child_id: child.id,
        prompt: "Check this",
        context: context,
        parent_llm: DiscourseAi::Completions::Llm.proxy(model),
      )
    expect(runner.run[:error]).to eq(I18n.t("discourse_ai.ai_bot.subagent_errors.call_limit"))
  end
end
