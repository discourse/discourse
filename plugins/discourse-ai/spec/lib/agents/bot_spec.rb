# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Bot do
  subject(:bot) { described_class.as(admin, agent: DiscourseAi::Agents::General.new, model: gpt_4) }

  fab!(:admin)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:fake) { Fabricate(:llm_model, name: "fake", provider: "fake") }
  fab!(:user)

  let(:bot_user) { admin }

  before { prepare_ai_bot_fixtures(bots: [gpt_4]) }

  let(:function_call) { <<~TEXT }
    Let me try using a function to get more info:<function_calls>
    <invoke>
    <tool_name>categories</tool_name>
    </invoke>
    </function_calls>
  TEXT

  let(:response) { "As expected, your forum has multiple tags" }

  let(:llm_responses) { [function_call, response] }

  describe ".effective_max_turn_tokens" do
    it "defaults to the model context window while keeping explicit allowances exact" do
      [4096, 200_000, nil].each do |context_window|
        model = instance_double(DiscourseAi::Completions::Llm, max_prompt_tokens: context_window)
        default = context_window || described_class::FALLBACK_MAX_TURN_TOKENS
        expect(described_class.effective_max_turn_tokens(model, 8000)).to eq(8000)
        expect(described_class.effective_max_turn_tokens(model, 60_000)).to eq(60_000)
        expect(described_class.effective_max_turn_tokens(model, 10)).to eq(10)
        expect(described_class.default_max_turn_tokens(model)).to eq(default)
        expect(
          described_class.effective_max_turn_tokens(
            model,
            4000,
            compression_threshold: 50,
            max_tokens: 1,
            thinking_effort: "high",
          ),
        ).to eq(4000)
        expect(described_class.default_max_turn_tokens(model, compression_threshold: 50)).to eq(
          default,
        )
      end
    end
  end

  describe "#reply" do
    it "sets top_p, temperature, and thinking_effort params" do
      SiteSetting.ai_llm_temperature_top_p_enabled = true
      DiscourseAi::Completions::Endpoints::Fake.delays = []
      DiscourseAi::Completions::Endpoints::Fake.last_call = nil

      toggle_enabled_bots(bots: [fake])
      Group.refresh_automatic_groups!

      bot_user = admin
      AiAgent.create!(
        name: "TestAgent",
        top_p: 0.5,
        temperature: 0.4,
        thinking_effort: "high",
        system_prompt: "test",
        description: "test",
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      )

      agentClass = DiscourseAi::Agents::Agent.find_by(user: admin, name: "TestAgent")

      bot = described_class.as(bot_user, agent: agentClass.new, model: fake)
      bot.reply(
        DiscourseAi::Agents::BotContext.new(messages: [{ type: :user, content: "test" }]),
      ) { |_partial, _cancel, _placeholder| }

      last_call = DiscourseAi::Completions::Endpoints::Fake.last_call
      expect(last_call[:model_params]).to include(
        top_p: 0.5,
        temperature: 0.4,
        thinking_effort: "high",
      )
    end

    it "requests Gemini thought summaries when thinking is shown" do
      gemini = Fabricate(:gemini_model)
      captured_kwargs = []
      bot = described_class.as(bot_user, agent: DiscourseAi::Agents::General.new, model: gemini)
      context =
        DiscourseAi::Agents::BotContext.new(
          messages: [{ type: :user, content: "test" }],
          skip_show_thinking: false,
        )

      allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
        :generate,
      ) do |_, *_args, **kwargs|
        captured_kwargs << kwargs
        "Answer"
      end

      bot.reply(context) { |_partial| }

      expect(captured_kwargs.first[:extra_model_params]).to include(include_thought_summaries: true)
    end

    it "does not request Gemini thought summaries when thinking is hidden" do
      gemini = Fabricate(:gemini_model)
      captured_kwargs = []
      bot = described_class.as(bot_user, agent: DiscourseAi::Agents::General.new, model: gemini)
      context =
        DiscourseAi::Agents::BotContext.new(
          messages: [{ type: :user, content: "test" }],
          skip_show_thinking: true,
        )

      allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
        :generate,
      ) do |_, *_args, **kwargs|
        captured_kwargs << kwargs
        "Answer"
      end

      bot.reply(context) { |_partial| }

      expect(captured_kwargs.first[:extra_model_params]).to be_nil
    end

    it "adds subagent attribution without leaking unrelated context metadata" do
      context =
        DiscourseAi::Agents::BotContext.new(
          user: user,
          messages: [{ type: :user, content: "test" }],
          feature_context: {
            :source => "context",
            "subagent_depth" => 1,
            "subagent_agent_id" => 7,
          },
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Done"],
      ) do |_endpoint, _llm, _, options|
        bot.reply(
          context,
          llm_args: {
            feature_context: {
              post_id: 42,
              source: "caller",
              subagent_depth: 99,
            },
          },
        )

        expect(options.first[:feature_context]).to eq(
          "post_id" => 42,
          "source" => "caller",
          "subagent_depth" => 1,
          "subagent_agent_id" => 7,
        )
      end
    end

    it "uses the reserved final completion when the shared completion budget is exhausted" do
      execution_context =
        DiscourseAi::Completions::ExecutionContext.new(
          token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
        )
      state =
        DiscourseAi::Agents::SubagentExecutionState.new(
          execution_context: execution_context,
          root_token_budget: 10_000,
        )
      (DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS - 1).times do
        expect(state.reserve_completion).to eq(true)
      end
      context =
        DiscourseAi::Agents::BotContext.new(
          user: user,
          messages: [{ type: :user, content: "test" }],
          execution_context: execution_context,
          subagent_execution_state: state,
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Final answer"],
      ) do |_endpoint, _llm, prompts|
        bot.reply(context)

        expect(prompts.first.tool_choice).to eq(:none)
        expect(prompts.first.messages.last[:content]).to eq(
          described_class::COMPLETION_LIMIT_FINAL_ANSWER_HINT,
        )
      end
    end

    context "when using function chaining" do
      it "yields a loading placeholder while proceeds to invoke the command" do
        tool = DiscourseAi::Agents::Tools::ListCategories.new({}, bot_user: nil, llm: nil)
        partial_placeholder = +<<~HTML
        <details>
          <summary>#{tool.summary}</summary>
          <p></p>
        </details>
        <span></span>

        HTML

        context =
          DiscourseAi::Agents::BotContext.new(
            messages: [{ type: :user, content: "Does my site has tags?" }],
          )

        DiscourseAi::Completions::Llm.with_prepared_responses(llm_responses) do
          bot.reply(context) do |_bot_reply_post, cancel, placeholder|
            expect(placeholder).to eq(partial_placeholder) if placeholder
          end
        end
      end
    end

    context "with tool invocation limits" do
      fab!(:agent_record) do
        Fabricate(
          :ai_agent,
          tools: [["Search", { "max_results" => 3, "max_invocations" => 1 }, false]],
        )
      end

      it "keeps delegation available after a limited evidence tool is exhausted" do
        Group.refresh_automatic_groups!
        child =
          Fabricate(
            :ai_agent,
            default_llm_id: gpt_4.id,
            allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          )
        parent =
          Fabricate(
            :ai_agent,
            default_llm_id: gpt_4.id,
            allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
            subagent_ids: [child.id],
            tools: [["Search", { "max_results" => 3, "max_invocations" => 1 }, false]],
          )
        search_call =
          DiscourseAi::Completions::ToolCall.new(
            id: "search-1",
            name: "search",
            parameters: {
              search_query: "distinctive phrase",
            },
          )
        spawn_call =
          DiscourseAi::Completions::ToolCall.new(
            id: "spawn-1",
            name: "spawn_agent",
            parameters: {
              agent_id: child.id,
              prompt: "Check the evidence",
            },
          )
        context =
          DiscourseAi::Agents::BotContext.new(
            user: user,
            messages: [{ type: :user, content: "Verify this" }],
          )

        DiscourseAi::Completions::Llm.with_prepared_responses(
          [search_call, spawn_call, "Child result", "Final answer"],
        ) do |_endpoint, _llm, prompts|
          agent_bot = described_class.as(bot_user, agent: parent.class_instance.new, model: gpt_4)
          raw_context = agent_bot.reply(context) { |_partial| }

          expect(raw_context.last.first).to eq("Final answer")
          expect(prompts[1].tool_choice).not_to eq(:none)
          expect(prompts.last.tool_choice).not_to eq(:none)
        end
      end

      it "runs one invocation and requests a final answer when a model emits parallel calls" do
        first_tool_call =
          DiscourseAi::Completions::ToolCall.new(
            id: "call_1",
            name: "search",
            parameters: {
              search_query: "distinctive phrase",
            },
          )
        second_tool_call =
          DiscourseAi::Completions::ToolCall.new(
            id: "call_2",
            name: "search",
            parameters: {
              search_query: "rephrased distinctive phrase",
            },
          )
        context =
          DiscourseAi::Agents::BotContext.new(
            user: user,
            messages: [{ type: :user, content: "Find the source" }],
          )

        DiscourseAi::Completions::Llm.with_prepared_responses(
          [[first_tool_call, second_tool_call], "Final answer"],
        ) do |_endpoint, _llm, prompts|
          agent_bot =
            described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4)
          raw_context = agent_bot.reply(context) { |_partial| }
          tool_results = prompts.last.messages.select { |message| message[:type] == :tool }

          expect(raw_context.last.first).to eq("Final answer")
          expect(prompts.map(&:tool_choice)).to eq([nil, :none])
          expect(tool_results.length).to eq(2)
          expect(
            tool_results.count { |result| JSON.parse(result[:content])["status"] == "error" },
          ).to eq(1)
          expect(prompts.last.messages.last).to eq(
            type: :user,
            content: described_class::TOOL_INVOCATION_BUDGET_FINAL_ANSWER_HINT,
          )
        end
      end
    end

    context "with token budget execution" do
      fab!(:agent_record) do
        Fabricate(
          :ai_agent,
          max_turn_tokens: 5000,
          compression_threshold: 80,
          tools: [["ListCategories", nil, false]],
        )
      end

      let(:agent_class) { agent_record.class_instance }

      %i[text tools final].each do |mode|
        it "prepares tight-window #{mode} calls with their admitted output instead of the model ceiling" do
          gpt_4.update!(max_prompt_tokens: 16_000, max_output_tokens: 12_000)
          agent_record.update!(
            max_turn_tokens: 4000,
            tools: mode == :tools ? [["ListCategories", nil, false]] : [],
          )
          execution =
            DiscourseAi::Completions::ExecutionContext.new(
              work_budget:
                DiscourseAi::Completions::TurnWorkBudget.new(
                  limit: 4000,
                  used: mode == :final ? 4000 : 0,
                ),
            )
          context =
            DiscourseAi::Agents::BotContext.new(
              user: user,
              messages: [{ type: :user, content: "input " * 8000 }],
            )
          DiscourseAi::Completions::Llm.with_prepared_responses(
            ["Fitting answer"],
          ) do |_, _, prompts, options|
            agent_bot =
              described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4)
            expect(agent_bot.reply(context, execution_context: execution).last.first).to eq(
              "Fitting answer",
            )
            expect(options.map { |option| option[:max_tokens] }).to eq(
              [mode == :tools ? 2000 : mode == :final ? 2048 : 4000],
            )
            expect(options.map { |option| option[:feature_name] }).to eq(["bot"])
            expect(prompts.first.tool_choice).to eq(mode == :final ? :none : nil)
            expect(context.execution_context.work_budget.limit).to eq(4000)
            expect(context.execution_context.work_budget.used).to eq(
              (mode == :final ? 4000 : 0) + agent_bot.llm.tokenizer.size("Fitting answer"),
            )
            expect(
              DiscourseAi::Completions::PromptMessagesBuilder.message_text(
                prompts.first.messages[1],
              ),
            ).to include(context.messages.first[:content])
            expect(execution.work_budget.limit).to eq(4000)
          end
        end
      end

      it "starts fresh work for a second root reply while retaining the actual usage tracker" do
        agent_record.update!(max_turn_tokens: 4000, tools: [])
        execution = DiscourseAi::Completions::ExecutionContext.new
        context =
          DiscourseAi::Agents::BotContext.new(
            user: user,
            messages: [{ type: :user, content: "Answer" }],
          )
        agent_bot =
          described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4)
        DiscourseAi::Completions::Llm.with_prepared_responses(%w[First Second Third]) do
          agent_bot.reply(context, execution_context: execution)
          first_work = context.execution_context.work_budget
          first_work.debit(5000, event_id: "exhausted previous turn")
          tracker = context.execution_context.token_usage_tracker
          tracker.add_effective(request: 10, response: 20)
          agent_bot.reply(context, execution_context: execution)
          expect(context.execution_context.work_budget.used).to eq(
            agent_bot.llm.tokenizer.size("Second"),
          )
          expect(context.execution_context.work_budget.limit).to eq(4000)
          expect(context.execution_context.token_usage_tracker).to eq(tracker)
          expect(tracker.total).to eq(30)
          agent_bot.reply(context)
          expect(context.execution_context.work_budget.used).to eq(
            agent_bot.llm.tokenizer.size("Third"),
          )
          expect(first_work.used).to be > 4000
        end
      end

      it "keeps the final claim available when the provider cannot honor the final output ceiling" do
        execution =
          DiscourseAi::Completions::ExecutionContext.new(
            work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000, used: 4000),
          )
        context =
          DiscourseAi::Agents::BotContext.new(
            user: user,
            messages: [{ type: :user, content: "Answer" }],
          )
        # Simulate a provider whose mandatory reasoning cannot be disabled for finalization.
        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :prompt_capacity,
        ).and_return([100, 20_000, 4096])
        DiscourseAi::Completions::Llm.with_prepared_responses([]) do |canned|
          expect {
            described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4).reply(
              context,
              execution_context: execution,
            )
          }.to raise_error(
            DiscourseAi::Completions::ContextPreparation::Error,
            /final_output_limit/,
          )
          expect(canned.completions).to eq(0)
        end
        expect(execution.work_budget.snapshot[:final_answer_claimed]).to eq(false)
        expect(execution.work_budget.remaining).to eq(0)
      end

      it "excludes imported history from work and counts two fresh identical reads" do
        gpt_4.update!(max_prompt_tokens: 200_000, max_output_tokens: 50_000)
        agent_record.update!(max_turn_tokens: 4000, compression_threshold: 50)
        history = "Earlier evidence " * 1000
        calls =
          2.times.map do |index|
            DiscourseAi::Completions::ToolCall.new(
              id: "read-#{index}",
              name: "categories",
              parameters: {
              },
            )
          end
        DiscourseAi::Completions::Llm.with_prepared_responses(
          [*calls, "Final answer"],
        ) do |canned, _, prompts|
          agent_bot =
            described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4)
          context =
            DiscourseAi::Agents::BotContext.new(
              user: user,
              messages: [
                { type: :user, content: "Earlier request" },
                { type: :model, content: history },
                { type: :user, content: "Read twice" },
              ],
            )
          raw = agent_bot.reply(context)
          evidence = raw.select { |entry| entry[2] == "tool" }.map(&:first)
          expect(evidence.size).to eq(2)
          expect(evidence.first).to eq(evidence.second)
          tokenizer = agent_bot.llm.tokenizer
          generations =
            [*calls, "Final answer"].sum do |part|
              output = DiscourseAi::Completions::GeneratedOutput.new
              output << part
              output.size(tokenizer)
            end
          expect(context.execution_context.work_budget.used).to eq(
            generations + evidence.sum { |text| tokenizer.size(text) },
          )
          expect(context.execution_context.work_budget.limit).to eq(4000)
          expect(canned.completions).to eq(3)
          expect(prompts.map(&:tool_choice)).to eq([nil, nil, nil])
        end
        expect(agent_record.reload.max_turn_tokens).to eq(4000)
      end

      it "admits a huge tool result once and then gives only one bounded final answer" do
        result = { evidence: "External record QUARTZ-OTTER-731 " * 3000 }
        allow_any_instance_of(DiscourseAi::Agents::Tools::ListCategories).to receive(
          :invoke,
        ).and_return(result)
        gpt_4.update!(max_prompt_tokens: 200_000)
        call =
          DiscourseAi::Completions::ToolCall.new(
            id: "huge-read",
            name: "categories",
            parameters: {
            },
          )
        DiscourseAi::Completions::Llm.with_prepared_responses(
          [call, "Bounded final"],
        ) do |canned, _, prompts, options|
          agent_bot =
            described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4)
          context =
            DiscourseAi::Agents::BotContext.new(
              user: user,
              messages: [{ type: :user, content: "Read the evidence" }],
            )
          raw = agent_bot.reply(context)
          expect(raw.select { |entry| entry[2] == "tool" }.map(&:first)).to eq([result.to_json])
          expect(context.execution_context.work_budget.used).to be > 5000
          expect(prompts.last.tool_choice).to eq(:none)
          expect(options.last[:max_tokens]).to be <= described_class::MAX_FINAL_ANSWER_TOKENS
          expect(options.last[:thinking_effort]).to eq("none")
          expect(canned.completions).to eq(2)
          expect(context.execution_context.work_budget.snapshot[:final_answer_claimed]).to eq(true)
        end
      end

      it "bounds parallel execution even when a model emits more tools than an admitted batch" do
        calls =
          52.times.map do |index|
            DiscourseAi::Completions::ToolCall.new(
              id: "batch-#{index}",
              name: "categories",
              parameters: {
              },
            )
          end
        DiscourseAi::Completions::Llm.with_prepared_responses(
          [calls, "Batch summary"],
        ) do |_, _, prompts|
          agent_bot =
            described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4)
          context =
            DiscourseAi::Agents::BotContext.new(
              user: user,
              messages: [{ type: :user, content: "List many times" }],
            )
          raw = agent_bot.reply(context)
          results =
            raw.select { |entry| entry[2] == "tool" }.map { |entry| JSON.parse(entry.first) }
          expect(results.count { |result| result.key?("rows") }).to eq(50)
          expect(results.count { |result| result.key?("error") }).to eq(2)
          expect(prompts.last.tool_choice).to eq(:none)
          generation = DiscourseAi::Completions::GeneratedOutput.new
          calls.each { |call| generation << call }
          generation << "Batch summary"
          evidence =
            raw
              .select { |entry| entry[2] == "tool" }
              .sum { |entry| agent_bot.llm.tokenizer.size(entry.first) }
          expect(context.execution_context.work_budget.used).to eq(
            generation.size(agent_bot.llm.tokenizer) + evidence,
          )
        end
      end

      it "requests a final answer when the effective token budget is consumed" do
        gpt_4.update!(max_prompt_tokens: 9000)
        # budget=10000, first call adds 10000 tokens → reaches the threshold
        # and asks the second call to provide the final answer with tools disabled
        big_budget_agent =
          Fabricate(
            :ai_agent,
            max_turn_tokens: 10_000,
            compression_threshold: 80,
            tools: [["ListCategories", nil, false]],
          )

        klass = big_budget_agent.class_instance

        tool_call =
          DiscourseAi::Completions::ToolCall.new(id: "call_1", name: "categories", parameters: {})

        responses = [tool_call, "Done"]
        tool_choice_values = []
        prompt_messages = []

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          bot = described_class.as(bot_user, agent: klass.new, model: gpt_4)
          context =
            DiscourseAi::Agents::BotContext.new(
              messages: [{ type: :user, content: "List categories" }],
            )

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            prompt_arg = args.first
            tool_choice_values << prompt_arg.tool_choice
            prompt_messages << prompt_arg.messages.map(&:dup)
            result = original.call(*args, **kwargs, &blk)
            if (tracker = kwargs[:execution_context]&.token_usage_tracker)
              tracker.add_effective(request: 8000, response: 2000)
              kwargs[:execution_context].work_budget.debit(10_000, event_id: SecureRandom.uuid)
            end
            result
          end

          bot.reply(context) { |_partial| }
        end

        expect(tool_choice_values.first).not_to eq(:none)
        expect(tool_choice_values.last).to eq(:none)
        expect(
          prompt_messages.map do |messages|
            messages.count do |message|
              message[:content] == described_class::TOKEN_BUDGET_FINAL_ANSWER_HINT
            end
          end,
        ).to eq([0, 1])
        expect(prompt_messages.last.last).to eq(
          type: :user,
          content: described_class::TOKEN_BUDGET_FINAL_ANSWER_HINT,
        )
      end

      it "allows a final response when the tracker starts at the token budget" do
        tracker =
          DiscourseAi::Completions::TokenUsageTracker.new(
            base_request: described_class.effective_max_turn_tokens(bot.llm, 5000),
            base_response: 0,
          )
        execution_context =
          DiscourseAi::Completions::ExecutionContext.new(
            token_usage_tracker: tracker,
            work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 5000, used: 5000),
          )
        final_prompt = nil
        call_count = 0

        DiscourseAi::Completions::Llm.with_prepared_responses(["Final answer"]) do
          agent_bot = described_class.as(bot_user, agent: agent_class.new, model: gpt_4)
          context =
            DiscourseAi::Agents::BotContext.new(messages: [{ type: :user, content: "Answer" }])

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            final_prompt = args.first
            call_count += 1
            original.call(*args, **kwargs, &blk)
          end

          agent_bot.reply(context, execution_context:) { |_partial| }
        end

        expect(call_count).to eq(1)
        expect(final_prompt.tool_choice).to eq(:none)
        expect(final_prompt.messages.last).to eq(
          type: :user,
          content: described_class::TOKEN_BUDGET_FINAL_ANSWER_HINT,
        )
      end

      it "defaults the work allowance to the model context window" do
        no_budget_agent =
          Fabricate(
            :ai_agent,
            max_turn_tokens: nil,
            compression_threshold: 80,
            tools: [["ListCategories", nil, false]],
          )

        klass = no_budget_agent.class_instance

        expect(described_class.default_max_turn_tokens(bot.llm)).to eq(gpt_4.max_prompt_tokens)

        tool_call =
          DiscourseAi::Completions::ToolCall.new(id: "call_1", name: "categories", parameters: {})

        responses = [tool_call, "Final answer"]
        call_count = 0

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          agent_bot = described_class.as(bot_user, agent: klass.new, model: gpt_4)
          context =
            DiscourseAi::Agents::BotContext.new(messages: [{ type: :user, content: "test" }])

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            call_count += 1
            result = original.call(*args, **kwargs, &blk)
            # New generation consumes the default work allowance.
            if (tracker = kwargs[:execution_context]&.token_usage_tracker)
              tracker.add_effective(request: 90_000, response: 30_000)
              kwargs[:execution_context].work_budget.debit(
                gpt_4.max_prompt_tokens,
                event_id: SecureRandom.uuid,
              )
            end
            result
          end

          agent_bot.reply(context) { |_partial| }
        end

        expect(call_count).to eq(2)
      end

      it "rejects unknown capacity rather than trimming history" do
        DiscourseAi::Completions::Llm.with_prepared_responses(["Final answer"]) do |canned|
          agent_bot = described_class.as(bot_user, agent: agent_class.new, model: gpt_4)
          context =
            DiscourseAi::Agents::BotContext.new(messages: [{ type: :user, content: "test" }])
          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :max_prompt_tokens,
          ).and_return(0)

          expect { agent_bot.reply(context) }.to raise_error(
            DiscourseAi::Completions::ContextPreparation::Error,
            /unknown_capacity/,
          )
          expect(canned.completions).to eq(0)
        end
        expect(described_class.default_max_turn_tokens(nil)).to eq(
          described_class::FALLBACK_MAX_TURN_TOKENS,
        )
      end

      it "retains a tool-heavy previous turn despite a small work allowance" do
        gpt_4.update!(max_prompt_tokens: 200_000)
        agent_record.update!(max_turn_tokens: 4000, compression_threshold: 50)
        large_result = "Record: amber inventory item checked. " * 2000
        messages = [
          { type: :user, content: "Remember QUARTZ-OTTER-731" },
          { type: :tool_call, id: "read", name: "read", content: '{"arguments":{}}' },
          { type: :tool, id: "read", name: "read", content: large_result },
          { type: :model, content: "DATA READ" },
          { type: :user, content: "What codeword?" },
        ]
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["QUARTZ-OTTER-731"],
        ) do |canned, _, prompts, options|
          agent_bot =
            described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4)
          agent_bot.reply(DiscourseAi::Agents::BotContext.new(messages: messages))

          expect(canned.completions).to eq(1)
          expect(options.first[:feature_name]).to eq("bot")
          expect(prompts.first.messages.drop(1)).to eq(messages)
          expect(prompts.first.skip_trim).to eq(true)
        end
      end

      it "prepares a completed turn before answering and persists the checkpoint and current request" do
        gpt_4.update!(max_prompt_tokens: 16_000)
        agent_record.update!(max_turn_tokens: 4000, compression_threshold: 50)
        large_result = "Record: amber inventory item checked. " * 1600
        latest_request = "What codeword?"
        messages = [
          { type: :user, content: "Remember QUARTZ-OTTER-731" },
          { type: :tool_call, id: "read", name: "read", content: '{"arguments":{}}' },
          { type: :tool, id: "read", name: "read", content: large_result },
          { type: :model, content: "DATA READ" },
          { type: :user, content: latest_request },
        ]
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["The user asked to remember QUARTZ-OTTER-731; the read succeeded.", "QUARTZ-OTTER-731"],
        ) do |_, _, prompts, options|
          agent_bot =
            described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4)
          context = DiscourseAi::Agents::BotContext.new(messages: messages, user: user)
          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &block|
            tracker = kwargs[:execution_context]&.token_usage_tracker
            maintenance = kwargs[:feature_name] == "context_compression"
            tracker&.add_effective(
              request: maintenance ? 10_000 : 3000,
              response: maintenance ? 200 : 100,
              preparation: maintenance,
            )
            original.call(*args, **kwargs, &block)
          end
          raw = agent_bot.reply(context)

          expect(options.map { |option| option[:feature_name] }).to eq(%w[context_compression bot])
          expect(options.first[:user]).to eq(user)
          expect(context.execution_context.token_usage_tracker.total).to eq(13_300)
          expect(prompts.last.tool_choice).not_to eq(:none)
          evidence = prompts.first.messages.last[:content]
          expect(evidence).to include("QUARTZ-OTTER-731", large_result)
          expect(evidence).not_to include(latest_request)
          expect(prompts.map(&:skip_trim)).to eq([true, true])
          expect(prompts.last.messages.last[:content]).to eq(latest_request)
          expect(raw.first[0]).to include("<compressed_context>")
          expect(raw.map(&:first)).to include(latest_request, "QUARTZ-OTTER-731")
        end
      end

      it "admits large current input without inflating the requested work allowance" do
        gpt_4.update!(max_prompt_tokens: 50_000)
        agent_record.update!(max_turn_tokens: 8000, compression_threshold: 50)
        context =
          DiscourseAi::Agents::BotContext.new(
            messages: [
              { type: :user, content: "Earlier request" },
              { type: :model, content: "Earlier evidence" },
              { type: :user, content: "input " * 30_000 },
            ],
          )
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["", "Answer using the full request"],
        ) do |_, _, prompts, options|
          agent_bot =
            described_class.as(bot_user, agent: agent_record.class_instance.new, model: gpt_4)
          agent_bot.reply(context)
          llm = agent_bot.llm
          input, _, output = llm.prompt_capacity(prompts.last)
          baseline = described_class.effective_max_turn_tokens(llm, 8000)

          expect(options.map { |option| option[:feature_name] }).to eq(%w[context_compression bot])
          expect(prompts.last.tool_choice).not_to eq(:none)
          expect(input + output).to be > baseline
          expect(context.subagent_execution_state.root_token_budget).to eq(8000)
          expect(context.execution_context.work_budget.used).to eq(
            agent_bot.llm.tokenizer.size("Answer using the full request"),
          )
          expect(agent_record.reload.max_turn_tokens).to eq(8000)
        end
      end

      it "forces a final text-only call after jumping past the token budget" do
        gpt_4.update!(max_prompt_tokens: 6000)
        small_budget_agent =
          Fabricate(
            :ai_agent,
            max_turn_tokens: 2000,
            compression_threshold: 80,
            tools: [["ListCategories", nil, false]],
          )

        klass = small_budget_agent.class_instance

        tool_call =
          DiscourseAi::Completions::ToolCall.new(id: "call_1", name: "categories", parameters: {})

        responses = [tool_call, "Here is my summary based on what I found."]
        call_count = 0
        prompt_messages = []
        tool_choice_values = []

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          bot = described_class.as(bot_user, agent: klass.new, model: gpt_4)
          context =
            DiscourseAi::Agents::BotContext.new(
              messages: [{ type: :user, content: "List categories" }],
            )

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            call_count += 1
            prompt_arg = args.first
            tool_choice_values << prompt_arg.tool_choice
            prompt_messages << prompt_arg.messages.map(&:dup)
            result = original.call(*args, **kwargs, &blk)
            if (tracker = kwargs[:execution_context]&.token_usage_tracker)
              tracker.add_effective(request: 8500, response: 500)
              kwargs[:execution_context].work_budget.debit(2500, event_id: SecureRandom.uuid)
            end
            result
          end

          bot.reply(context) { |_partial| }
        end

        expect(call_count).to eq(2)
        expect(tool_choice_values[0]).not_to eq(:none)
        expect(tool_choice_values[1]).to eq(:none)
        expect(prompt_messages.last.last).to eq(
          type: :user,
          content: described_class::TOKEN_BUDGET_FINAL_ANSWER_HINT,
        )
      end

      it "keeps the caller execution context intact on error" do
        responses = [RuntimeError.new("boom")]
        tracker = DiscourseAi::Completions::TokenUsageTracker.new
        execution_context =
          DiscourseAi::Completions::ExecutionContext.new(
            token_usage_tracker: tracker,
            work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 5000, used: 5000),
          )

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          bot = described_class.as(bot_user, agent: agent_class.new, model: gpt_4)
          context =
            DiscourseAi::Agents::BotContext.new(messages: [{ type: :user, content: "test" }])

          expect { bot.reply(context, execution_context:) { |_partial| } }.to raise_error(
            RuntimeError,
            "boom",
          )
          expect(execution_context.token_usage_tracker).to eq(tracker)
        end
      end
    end
  end

  describe "#invoke_tool with require_approval" do
    fab!(:topic)

    it "creates a reviewable instead of executing when require_approval is true" do
      toggle_enabled_bots(bots: [fake])
      Group.refresh_automatic_groups!

      AiAgent.create!(
        name: "ApprovalAgent",
        system_prompt: "test",
        description: "test",
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        require_approval: true,
      )

      agent_class = DiscourseAi::Agents::Agent.find_by(user: admin, name: "ApprovalAgent")
      test_bot_user = admin
      bot = described_class.as(test_bot_user, agent: agent_class.new, model: fake)

      tool =
        DiscourseAi::Agents::Tools::CloseTopic.new(
          { topic_id: topic.id, closed: true, reason: "Off-topic" },
          bot_user: test_bot_user,
          llm: bot.llm,
        )

      context = DiscourseAi::Agents::BotContext.new(messages: [])

      result = bot.send(:invoke_tool, tool, context) { |*args| }

      expect(result[:status]).to eq("pending_approval")
      expect(topic.reload.closed).to eq(false)
      expect(AiToolAction.last.tool_name).to eq("close_topic")
      expect(ReviewableAiToolAction.count).to eq(1)
    end

    it "rejects a site setting change requested by a moderator before queueing it" do
      toggle_enabled_bots(bots: [fake])
      Group.refresh_automatic_groups!
      moderator = Fabricate(:moderator)

      approval_agent =
        AiAgent.create!(
          name: "ModeratorApprovalAgent",
          system_prompt: "test",
          description: "test",
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          require_approval: true,
          tools: [["ChangeSiteSetting", nil, false]],
        )

      agent_class = approval_agent.class_instance
      test_bot_user = admin
      bot = described_class.as(test_bot_user, agent: agent_class.new, model: fake)
      tool =
        DiscourseAi::Agents::Tools::ChangeSiteSetting.new(
          { setting_name: "min_post_length", value: "42", reason: "Testing" },
          bot_user: test_bot_user,
          llm: bot.llm,
          context: DiscourseAi::Agents::BotContext.new(user: moderator),
        )

      result = nil
      expect { result = bot.send(:invoke_tool, tool, tool.context) { |*args| } }.not_to change {
        [AiToolAction.count, ReviewableAiToolAction.count]
      }

      expect(result[:status]).to eq("error")
      expect(result[:error]).to eq(
        I18n.t("discourse_ai.ai_bot.change_site_setting.errors.not_allowed"),
      )
      expect(SiteSetting.min_post_length).not_to eq(42)
    end

    it "rejects a secret site setting change before queueing it" do
      toggle_enabled_bots(bots: [fake])
      Group.refresh_automatic_groups!

      approval_agent =
        AiAgent.create!(
          name: "SecretSettingApprovalAgent",
          system_prompt: "test",
          description: "test",
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          require_approval: true,
          tools: [["ChangeSiteSetting", nil, false]],
        )

      agent_class = approval_agent.class_instance
      test_bot_user = admin
      bot = described_class.as(test_bot_user, agent: agent_class.new, model: fake)
      secret_value = "new-discourse-connect-secret"
      tool =
        DiscourseAi::Agents::Tools::ChangeSiteSetting.new(
          { setting_name: "discourse_connect_secret", value: secret_value, reason: "Testing" },
          bot_user: test_bot_user,
          llm: bot.llm,
          context: DiscourseAi::Agents::BotContext.new(user: admin),
        )

      result = nil
      expect { result = bot.send(:invoke_tool, tool, tool.context) { |*args| } }.not_to change {
        [AiToolAction.count, ReviewableAiToolAction.count]
      }

      expect(result[:status]).to eq("error")
      expect(result[:error]).to eq(
        I18n.t(
          "discourse_ai.ai_bot.change_site_setting.errors.secret",
          setting_name: "discourse_connect_secret",
        ),
      )
      expect(result[:error]).not_to include(secret_value)
    end

    it "queues mandatory approval tools when require_approval is false" do
      toggle_enabled_bots(bots: [fake])
      Group.refresh_automatic_groups!
      target_user = Fabricate(:user)
      mandatory_approval_agent =
        AiAgent.create!(
          name: "MandatoryApprovalAgent",
          system_prompt: "test",
          description: "test",
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          require_approval: false,
          tools: %w[SuspendUser SilenceUser ChangeSiteSetting],
        )
      agent_class = mandatory_approval_agent.class_instance
      bot = described_class.as(admin, agent: agent_class.new, model: fake)
      context = DiscourseAi::Agents::BotContext.new(user: admin)
      tools = [
        DiscourseAi::Agents::Tools::SuspendUser.new(
          { username: target_user.username, duration_days: 3, reason: "Testing" },
          bot_user: admin,
          llm: bot.llm,
          context: context,
        ),
        DiscourseAi::Agents::Tools::SilenceUser.new(
          { username: target_user.username, duration_days: 3, reason: "Testing" },
          bot_user: admin,
          llm: bot.llm,
          context: context,
        ),
        DiscourseAi::Agents::Tools::ChangeSiteSetting.new(
          { setting_name: "min_post_length", value: "42", reason: "Testing" },
          bot_user: admin,
          llm: bot.llm,
          context: context,
        ),
      ]

      results = tools.map { |tool| bot.send(:invoke_tool, tool, context) { |*args| } }

      expect(results).to all(include(status: "pending_approval"))
      expect(target_user.reload).not_to be_suspended
      expect(SiteSetting.min_post_length).not_to eq(42)
      expect(ReviewableAiToolAction.count).to eq(3)
    end

    it "executes immediately when require_approval is false" do
      toggle_enabled_bots(bots: [fake])
      Group.refresh_automatic_groups!

      AiAgent.create!(
        name: "NoApprovalAgent",
        system_prompt: "test",
        description: "test",
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        require_approval: false,
      )

      agent_class = DiscourseAi::Agents::Agent.find_by(user: admin, name: "NoApprovalAgent")
      test_bot_user = admin
      bot = described_class.as(test_bot_user, agent: agent_class.new, model: fake)

      tool =
        DiscourseAi::Agents::Tools::CloseTopic.new(
          { topic_id: topic.id, closed: true, reason: "Off-topic" },
          bot_user: test_bot_user,
          llm: bot.llm,
        )

      context = DiscourseAi::Agents::BotContext.new(messages: [])

      result = bot.send(:invoke_tool, tool, context) { |*args| }

      expect(result[:status]).to eq("success")
      expect(topic.reload.closed).to eq(true)
      expect(ReviewableAiToolAction.count).to eq(0)
    end

    it "does not create a reviewable when the tool's args are invalid" do
      toggle_enabled_bots(bots: [fake])
      Group.refresh_automatic_groups!

      failing_precheck_tool_class =
        Class.new(DiscourseAi::Agents::Tools::CloseTopic) do
          def validation_error
            error_response("nope")
          end
        end

      AiAgent.create!(
        name: "PrecheckAgent",
        system_prompt: "test",
        description: "test",
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        require_approval: true,
      )

      agent_class = DiscourseAi::Agents::Agent.find_by(user: admin, name: "PrecheckAgent")
      test_bot_user = admin
      bot = described_class.as(test_bot_user, agent: agent_class.new, model: fake)

      tool =
        failing_precheck_tool_class.new(
          { topic_id: topic.id, closed: true, reason: "Off-topic" },
          bot_user: test_bot_user,
          llm: bot.llm,
        )

      context = DiscourseAi::Agents::BotContext.new(messages: [])

      result = bot.send(:invoke_tool, tool, context) { |*args| }

      expect(result[:status]).to eq("error")
      expect(topic.reload.closed).to eq(false)
      expect(AiToolAction.count).to eq(0)
      expect(ReviewableAiToolAction.count).to eq(0)
    end
  end
end
