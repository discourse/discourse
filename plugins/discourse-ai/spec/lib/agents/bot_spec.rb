# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Bot do
  subject(:bot) { described_class.as(bot_user, agent: DiscourseAi::Agents::General.new) }

  fab!(:admin)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:fake) { Fabricate(:llm_model, name: "fake", provider: "fake") }

  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [gpt_4])
    SiteSetting.ai_bot_enabled = true
  end

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(gpt_4.name) }

  let!(:user) { Fabricate(:user) }

  let(:function_call) { <<~TEXT }
    Let me try using a function to get more info:<function_calls>
    <invoke>
    <tool_name>categories</tool_name>
    </invoke>
    </function_calls>
  TEXT

  let(:response) { "As expected, your forum has multiple tags" }

  let(:llm_responses) { [function_call, response] }

  describe "#reply" do
    it "sets top_p, temperature, and thinking_effort params" do
      SiteSetting.ai_llm_temperature_top_p_enabled = true
      DiscourseAi::Completions::Endpoints::Fake.delays = []
      DiscourseAi::Completions::Endpoints::Fake.last_call = nil

      toggle_enabled_bots(bots: [fake])
      Group.refresh_automatic_groups!

      bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model(fake.name)
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

      bot = described_class.as(bot_user, agent: agentClass.new)
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

      it "stops the loop when token budget is exhausted" do
        tool_call =
          DiscourseAi::Completions::ToolCall.new(id: "call_1", name: "categories", parameters: {})

        responses = [tool_call, "Final answer"]
        call_count = 0

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          bot = described_class.as(bot_user, agent: agent_class.new)
          context =
            DiscourseAi::Agents::BotContext.new(
              messages: [{ type: :user, content: "List categories" }],
            )

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            call_count += 1
            result = original.call(*args, **kwargs, &blk)
            if (tracker = kwargs[:execution_context]&.token_usage_tracker)
              tracker.add_effective(request: 3000, response: 500)
            end
            result
          end

          bot.reply(context) { |_partial| }
        end

        # first call: 3500 tokens (under 5000), tool runs
        # second call: 7000 total (over 5000), loop breaks after this call
        expect(call_count).to eq(2)
      end

      it "sets tool_choice to :none when 85% of budget is consumed" do
        # budget=10000, 85%=8500
        # first call adds 9000 tokens → crosses 85% but under 10000 → sets tool_choice=:none
        # second call sees tool_choice=:none in the prompt
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

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          bot = described_class.as(bot_user, agent: klass.new)
          context =
            DiscourseAi::Agents::BotContext.new(
              messages: [{ type: :user, content: "List categories" }],
            )

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            prompt_arg = args.first
            tool_choice_values << prompt_arg.tool_choice
            result = original.call(*args, **kwargs, &blk)
            if (tracker = kwargs[:execution_context]&.token_usage_tracker)
              tracker.add_effective(request: 8000, response: 1000)
            end
            result
          end

          bot.reply(context) { |_partial| }
        end

        expect(tool_choice_values[0]).not_to eq(:none)
        expect(tool_choice_values[1]).to eq(:none)
      end

      it "defaults the turn budget to half the context window without max_turn_tokens" do
        no_budget_agent =
          Fabricate(
            :ai_agent,
            max_turn_tokens: nil,
            compression_threshold: 80,
            tools: [["ListCategories", nil, false]],
          )

        klass = no_budget_agent.class_instance

        # gpt_4 has max_prompt_tokens 131_072, so the default budget is 65_536.
        expect(DiscourseAi::Agents::Bot.default_max_turn_tokens(bot.send(:llm))).to eq(65_536)

        tool_call =
          DiscourseAi::Completions::ToolCall.new(id: "call_1", name: "categories", parameters: {})

        responses = [tool_call, "Final answer"]
        call_count = 0

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          agent_bot = described_class.as(bot_user, agent: klass.new)
          context =
            DiscourseAi::Agents::BotContext.new(messages: [{ type: :user, content: "test" }])

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            call_count += 1
            result = original.call(*args, **kwargs, &blk)
            # 70_000 tokens per call exceeds the 65_536 default budget after the
            # first call, so the loop stops on the token budget.
            if (tracker = kwargs[:execution_context]&.token_usage_tracker)
              tracker.add_effective(request: 40_000, response: 30_000)
            end
            result
          end

          agent_bot.reply(context) { |_partial| }
        end

        expect(call_count).to eq(2)
      end

      it "uses conservative default budget and keeps trimming for models without a context window" do
        no_budget_agent =
          Fabricate(
            :ai_agent,
            max_turn_tokens: nil,
            compression_threshold: 80,
            tools: [["ListCategories", nil, false]],
          )

        captured_skip_trim = nil

        DiscourseAi::Completions::Llm.with_prepared_responses(["Final answer"]) do
          agent_bot = described_class.as(bot_user, agent: no_budget_agent.class_instance.new)
          context =
            DiscourseAi::Agents::BotContext.new(messages: [{ type: :user, content: "test" }])

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :max_prompt_tokens,
          ).and_return(0)
          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            captured_skip_trim = args.first.skip_trim
            original.call(*args, **kwargs, &blk)
          end

          agent_bot.reply(context) { |_partial| }
        end

        expect(described_class.default_max_turn_tokens(nil)).to eq(
          described_class::DEFAULT_MAX_TURN_TOKENS,
        )
        expect(captured_skip_trim).to be_falsey
      end

      it "uses explicit max_turn_tokens to size the initial context budget" do
        llm = bot.send(:llm)

        expect(described_class.context_token_budget(llm, 5000)).to eq(2500)
      end

      it "defaults context budget to half of the default turn budget" do
        llm = bot.send(:llm)

        expect(described_class.context_token_budget(llm)).to eq(32_768)
      end

      it "re-enables dialect trimming when compression fails" do
        large_messages = [{ type: :user, content: "Start" }]
        10.times do |index|
          large_messages << { type: :model, content: "Response #{index} " * 200 }
          large_messages << { type: :user, content: "Message #{index} " * 200 }
        end

        main_generate_skip_trim_values = []

        DiscourseAi::Completions::Llm.with_prepared_responses(["Done"]) do
          agent_bot = described_class.as(bot_user, agent: agent_class.new)
          context = DiscourseAi::Agents::BotContext.new(messages: large_messages)

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :max_prompt_tokens,
          ).and_return(2000)
          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(:tokenizer).and_return(
            DiscourseAi::Tokenizer::OpenAiTokenizer,
          )
          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            if kwargs[:feature_name] == "context_compression"
              raise RuntimeError, "compression failed"
            end

            main_generate_skip_trim_values << args.first.skip_trim
            original.call(*args, **kwargs, &blk)
          end

          agent_bot.reply(context) { |_partial| }
        end

        expect(main_generate_skip_trim_values).to eq([false])
      end

      it "re-enables dialect trimming when compression still leaves the prompt over threshold" do
        large_messages = [{ type: :user, content: "Start" }]
        10.times do |index|
          large_messages << { type: :model, content: "Response #{index} " * 200 }
          large_messages << { type: :user, content: "Message #{index} " * 200 }
        end
        large_messages << { type: :model, content: "Latest oversized response " * 1000 }

        main_generate_skip_trim_values = []

        DiscourseAi::Completions::Llm.with_prepared_responses(["Done"]) do
          agent_bot = described_class.as(bot_user, agent: agent_class.new)
          context = DiscourseAi::Agents::BotContext.new(messages: large_messages)

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :max_prompt_tokens,
          ).and_return(2000)
          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(:tokenizer).and_return(
            DiscourseAi::Tokenizer::OpenAiTokenizer,
          )
          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            if kwargs[:feature_name] == "context_compression"
              "Summary of the conversation."
            else
              main_generate_skip_trim_values << args.first.skip_trim
              original.call(*args, **kwargs, &blk)
            end
          end

          agent_bot.reply(context) { |_partial| }
        end

        expect(main_generate_skip_trim_values).to eq([false])
      end

      it "forces a final text-only call with budget hint when budget exhausted after tool execution" do
        # budget=2000, first call adds 3000 tokens → tool runs → budget exceeded
        # but prompt ends with :tool, so model gets one more tool_choice=:none call
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
          bot = described_class.as(bot_user, agent: klass.new)
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
            prompt_messages << prompt_arg.messages.map { |m| m[:type] }
            result = original.call(*args, **kwargs, &blk)
            if (tracker = kwargs[:execution_context]&.token_usage_tracker)
              tracker.add_effective(request: 2500, response: 500)
            end
            result
          end

          bot.reply(context) { |_partial| }
        end

        expect(call_count).to eq(2)
        expect(tool_choice_values[0]).not_to eq(:none)
        expect(tool_choice_values[1]).to eq(:none)
        # the budget hint was injected as a :user message before the final call
        expect(prompt_messages[1]).to include(:user)
      end

      it "keeps the caller execution context intact on error" do
        responses = [RuntimeError.new("boom")]
        tracker = DiscourseAi::Completions::TokenUsageTracker.new
        execution_context =
          DiscourseAi::Completions::ExecutionContext.new(token_usage_tracker: tracker)

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          bot = described_class.as(bot_user, agent: agent_class.new)
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

    describe "#maybe_compress_context" do
      fab!(:agent_record) do
        Fabricate(
          :ai_agent,
          max_turn_tokens: 500_000,
          compression_threshold: 75,
          tools: [["ListCategories", nil, false]],
        )
      end

      let(:agent_class) { agent_record.class_instance }

      it "compresses context when prompt exceeds default threshold of max_prompt_tokens" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [{ type: :system, content: "You are a bot" }]
        20.times do |i|
          messages << { type: :user, content: "Message #{i} " * 200 }
          messages << { type: :model, content: "Response #{i} " * 200 }
        end

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])

        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(2000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        compression_response = "Summary of the conversation."

        allow(llm).to receive(:generate).and_return(compression_response)

        bot.send(:maybe_compress_context, prompt, llm)

        expect(prompt.messages.first[:type]).to eq(:system)
        expect(prompt.messages[1][:type]).to eq(:user)
        expect(prompt.messages[1][:content]).to include("<compressed_context>")
        expect(prompt.messages[1][:content]).to include("Summary of the conversation.")
        expect(prompt.messages[2][:type]).to eq(:model)
        expect(prompt.messages[2][:content]).to eq("Understood, I have the context.")
        expect(prompt.messages.length).to be < 41
      end

      it "compacts raw context so compressed checkpoints persist to later turns" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [{ type: :system, content: "You are a bot" }]
        raw_context = []
        20.times do |index|
          user_message = { type: :user, content: "Message #{index} " * 200, id: user.username }
          model_message = { type: :model, content: "Response #{index} " * 200 }
          messages << user_message
          messages << model_message
          raw_context << [user_message[:content], user_message[:id], "user"]
          raw_context << [model_message[:content], nil, "model"]
        end

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])
        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(2000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)
        allow(llm).to receive(:generate).and_return("Summary of the conversation.")

        bot.send(:maybe_compress_context, prompt, llm, raw_context: raw_context)

        expect(raw_context.first).to eq(
          ["<compressed_context>Summary of the conversation.</compressed_context>", nil, "user"],
        )
        expect(raw_context.second).to eq(
          ["Understood, I have the context.", nil, "model", nil, nil],
        )
        expect(raw_context.flatten.join).not_to include("Message 0")
      end

      it "skips compression when under threshold" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [
          { type: :system, content: "You are a bot" },
          { type: :user, content: "Hello" },
          { type: :model, content: "Hi there" },
        ]

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])

        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(100_000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        bot.send(:maybe_compress_context, prompt, llm)

        expect(prompt.messages.length).to eq(3)
      end

      it "keeps the latest message even when it exceeds the tail budget" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [{ type: :system, content: "You are a bot" }]
        10.times do |index|
          messages << { type: :user, content: "Message #{index} " * 200 }
          messages << { type: :model, content: "Response #{index} " * 200 }
        end
        messages << { type: :user, content: "Latest request " * 1000 }

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])
        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(2000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)
        allow(llm).to receive(:generate).and_return("Summary of the conversation.")

        bot.send(:maybe_compress_context, prompt, llm)

        expect(prompt.messages.last[:content]).to include("Latest request")
        expect(prompt.messages[1][:content]).to include("<compressed_context>")
      end

      it "uses agent compression_threshold to control when compression triggers" do
        agent_record.update!(compression_threshold: 50)
        agent_class_with_threshold = agent_record.class_instance
        bot = described_class.as(bot_user, agent: agent_class_with_threshold.new)

        messages = [{ type: :system, content: "You are a bot" }]
        20.times do |i|
          messages << { type: :user, content: "Message #{i} " * 200 }
          messages << { type: :model, content: "Response #{i} " * 200 }
        end

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])

        llm = bot.send(:llm)
        # set max_prompt_tokens high enough that 75% wouldn't trigger but 50% does
        allow(llm).to receive(:max_prompt_tokens).and_return(20_000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        compression_response = "Compressed summary."

        allow(llm).to receive(:generate).and_return(compression_response)

        bot.send(:maybe_compress_context, prompt, llm)

        expect(prompt.messages[1][:content]).to include("<compressed_context>")
      end

      it "keeps tool_call/tool pairs together in the tail" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [{ type: :system, content: "You are a bot" }]
        # build enough middle messages to trigger compression
        6.times do |i|
          messages << { type: :user, content: "Question #{i} " * 200 }
          messages << { type: :model, content: "Answer #{i} " * 200 }
        end
        # add a tool_call/tool pair at the end so the pair must be retained as the tail
        messages << {
          type: :tool_call,
          id: "call_1",
          content: '{"arguments":{}}',
          name: "categories",
        }
        messages << { type: :tool, id: "call_1", content: "tool result", name: "categories" }

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])

        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(2000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        compression_response = "Compressed summary."

        allow(llm).to receive(:generate).and_return(compression_response)

        bot.send(:maybe_compress_context, prompt, llm)

        # verify tool_call and tool messages are both in the tail (not split)
        types = prompt.messages.map { |m| m[:type] }
        tool_call_idx = types.index(:tool_call)
        tool_idx = types.index(:tool)

        expect(tool_call_idx).to be_present
        expect(tool_idx).to eq(tool_call_idx + 1)

        # verify compression happened
        expect(prompt.messages[1][:content]).to include("<compressed_context>")
      end

      it "skips compression when summarization returns blank" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [{ type: :system, content: "You are a bot" }]
        20.times do |i|
          messages << { type: :user, content: "Message #{i} " * 200 }
          messages << { type: :model, content: "Response #{i} " * 200 }
        end

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])
        original_length = prompt.messages.length

        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(2000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        allow(llm).to receive(:generate).and_return("")

        bot.send(:maybe_compress_context, prompt, llm)

        expect(prompt.messages.length).to eq(original_length)
      end

      it "skips compression when summarization raises an error" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [{ type: :system, content: "You are a bot" }]
        20.times do |i|
          messages << { type: :user, content: "Message #{i} " * 200 }
          messages << { type: :model, content: "Response #{i} " * 200 }
        end

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])
        original_length = prompt.messages.length

        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(2000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        allow(llm).to receive(:generate).and_raise(RuntimeError, "API timeout")

        bot.send(:maybe_compress_context, prompt, llm)

        expect(prompt.messages.length).to eq(original_length)
      end

      it "skips compression when fewer than 6 middle messages" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [{ type: :system, content: "You are a bot" }]
        2.times do |i|
          messages << { type: :user, content: "Msg #{i} " * 200 }
          messages << { type: :model, content: "Reply #{i} " * 200 }
        end

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])

        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(500)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        original_length = prompt.messages.length
        bot.send(:maybe_compress_context, prompt, llm)

        expect(prompt.messages.length).to eq(original_length)
      end

      it "skips compression when summary is larger than the original middle messages" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [{ type: :system, content: "You are a bot" }]
        # use short messages so middle section is small
        10.times do |i|
          messages << { type: :user, content: "Message #{i} short" }
          messages << { type: :model, content: "Response #{i} short" }
        end

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])
        original_length = prompt.messages.length

        llm = bot.send(:llm)
        # set threshold low enough to trigger compression on short messages
        allow(llm).to receive(:max_prompt_tokens).and_return(50)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        inflated_summary = "Very long inflated summary output " * 500
        allow(llm).to receive(:generate).and_return(inflated_summary)

        bot.send(:maybe_compress_context, prompt, llm)

        expect(prompt.messages.length).to eq(original_length)
      end

      it "includes merge instruction when prior compressed context exists" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [
          { type: :system, content: "You are a bot" },
          { type: :user, content: "<compressed_context>Previous summary</compressed_context>" },
          { type: :model, content: "Understood, I have the context." },
        ]
        10.times do |i|
          messages << { type: :user, content: "Message #{i} " * 200 }
          messages << { type: :model, content: "Response #{i} " * 200 }
        end

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])

        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(2000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        compression_response = "Merged summary."
        compression_prompt_content = nil

        allow(llm).to receive(:generate) do |compression_prompt, **_kwargs|
          compression_prompt_content = compression_prompt.messages.last[:content]
          compression_response
        end

        bot.send(:maybe_compress_context, prompt, llm)

        expect(compression_prompt_content).to include("Merge the previous summary")
        expect(compression_prompt_content).to include(
          "Do not discard information from the previous summary",
        )
        expect(prompt.messages[1][:content]).to include("<compressed_context>")
        expect(prompt.messages[1][:content]).to include("Merged summary.")
      end

      it "does not include merge instruction when no prior compressed context exists" do
        bot = described_class.as(bot_user, agent: agent_class.new)

        messages = [{ type: :system, content: "You are a bot" }]
        20.times do |i|
          messages << { type: :user, content: "Message #{i} " * 200 }
          messages << { type: :model, content: "Response #{i} " * 200 }
        end

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages, tools: [])

        llm = bot.send(:llm)
        allow(llm).to receive(:max_prompt_tokens).and_return(2000)
        allow(llm).to receive(:tokenizer).and_return(DiscourseAi::Tokenizer::OpenAiTokenizer)

        compression_prompt_content = nil

        allow(llm).to receive(:generate) do |compression_prompt, **_kwargs|
          compression_prompt_content = compression_prompt.messages.last[:content]
          "Summary."
        end

        bot.send(:maybe_compress_context, prompt, llm)

        expect(compression_prompt_content).not_to include("Merge the previous summary")
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
      test_bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model(fake.name)
      bot = described_class.as(test_bot_user, agent: agent_class.new)

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
      test_bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model(fake.name)
      bot = described_class.as(test_bot_user, agent: agent_class.new)
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
      test_bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model(fake.name)
      bot = described_class.as(test_bot_user, agent: agent_class.new)

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
      test_bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model(fake.name)
      bot = described_class.as(test_bot_user, agent: agent_class.new)

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
