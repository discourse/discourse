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
    it "sets top_p and temperature params" do
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
      expect(last_call[:model_params][:top_p]).to eq(0.5)
      expect(last_call[:model_params][:temperature]).to eq(0.4)
    end

    context "when using function chaining" do
      it "yields a loading placeholder while proceeds to invoke the command" do
        tool = DiscourseAi::Agents::Tools::ListCategories.new({}, bot_user: nil, llm: nil)
        partial_placeholder = +(<<~HTML)
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

    context "with max_turn_tokens token budget" do
      fab!(:agent_record) do
        Fabricate(
          :ai_agent,
          execution_mode: "agentic",
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
            execution_mode: "agentic",
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

      it "preserves legacy MAX_COMPLETIONS behavior when max_turn_tokens is nil" do
        no_budget_agent =
          Fabricate(:ai_agent, max_turn_tokens: nil, tools: [["ListCategories", nil, false]])

        klass = no_budget_agent.class_instance
        expect(klass.max_turn_tokens).to be_nil

        tool_call =
          DiscourseAi::Completions::ToolCall.new(id: "call_1", name: "categories", parameters: {})

        # MAX_COMPLETIONS tool calls + 1 final text-only call (budget exhaustion path)
        responses = Array.new(described_class::MAX_COMPLETIONS) { tool_call } + ["Final"]
        call_count = 0

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          bot = described_class.as(bot_user, agent: klass.new)
          context =
            DiscourseAi::Agents::BotContext.new(messages: [{ type: :user, content: "test" }])

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            call_count += 1
            original.call(*args, **kwargs, &blk)
          end

          bot.reply(context) { |_partial| }
        end

        # +1 for the final text-only call after budget/turn exhaustion
        expect(call_count).to eq(described_class::MAX_COMPLETIONS + 1)
      end

      it "forces a final text-only call with budget hint when budget exhausted after tool execution" do
        # budget=2000, first call adds 3000 tokens → tool runs → budget exceeded
        # but prompt ends with :tool, so model gets one more tool_choice=:none call
        small_budget_agent =
          Fabricate(
            :ai_agent,
            execution_mode: "agentic",
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

      it "forces a final text-only call in legacy MAX_COMPLETIONS mode too" do
        one_turn_agent =
          Fabricate(:ai_agent, max_turn_tokens: nil, tools: [["ListCategories", nil, false]])

        klass = one_turn_agent.class_instance

        tool_call =
          DiscourseAi::Completions::ToolCall.new(id: "call_1", name: "categories", parameters: {})

        # MAX_COMPLETIONS tool calls, then one final text response
        responses = Array.new(described_class::MAX_COMPLETIONS) { tool_call } + ["Final summary"]
        call_count = 0
        last_tool_choice = nil

        DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
          bot = described_class.as(bot_user, agent: klass.new)
          context =
            DiscourseAi::Agents::BotContext.new(messages: [{ type: :user, content: "test" }])

          allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
            :generate,
          ).and_wrap_original do |original, *args, **kwargs, &blk|
            call_count += 1
            prompt_arg = args.first
            last_tool_choice = prompt_arg.tool_choice
            original.call(*args, **kwargs, &blk)
          end

          bot.reply(context) { |_partial| }
        end

        # MAX_COMPLETIONS tool calls + 1 final text-only call
        expect(call_count).to eq(described_class::MAX_COMPLETIONS + 1)
        expect(last_tool_choice).to eq(:none)
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
          execution_mode: "agentic",
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
        # add a tool_call/tool pair near the end
        messages << {
          type: :tool_call,
          id: "call_1",
          content: '{"arguments":{}}',
          name: "categories",
        }
        messages << { type: :tool, id: "call_1", content: "tool result", name: "categories" }
        messages << { type: :user, content: "Final question " * 200 }
        messages << { type: :model, content: "Final answer " * 200 }

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

        expect(tool_idx).to eq(tool_call_idx + 1) if tool_call_idx

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
end
