# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Agents::ToolRunner do
  fab!(:llm_model) { Fabricate(:llm_model, name: "claude-2") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  fab!(:bot_user) { Discourse.system_user }

  def create_tool(script:)
    AiTool.create!(
      name: "test #{SecureRandom.uuid}",
      tool_name: "test_#{SecureRandom.uuid.underscore}",
      description: "test",
      parameters: [{ name: "query", type: "string", description: "perform a search" }],
      script: script,
      created_by_id: 1,
      summary: "Test tool summary",
    )
  end

  before { enable_current_plugin }

  describe "LLM operations" do
    it "shares tool-owned generation, reasoning usage and in-flight work with the root" do
      requests = []
      request =
        stub_request(:post, llm_model.url).with(
          body:
            proc do |body|
              requests << JSON.parse(body)
              true
            end,
        ).to_return(
          body: {
            usage: {
              prompt_tokens: 500,
              completion_tokens: 37,
              completion_tokens_details: {
                reasoning_tokens: 30,
              },
            },
            choices: [
              { message: { role: "assistant", content: "Helper output" }, finish_reason: "stop" },
            ],
          }.to_json,
        )
      execution =
        DiscourseAi::Completions::ExecutionContext.new(
          token_usage_tracker: DiscourseAi::Completions::TokenUsageTracker.new,
        )
      state =
        DiscourseAi::Agents::SubagentExecutionState.new(
          execution_context: execution,
          root_token_budget: 4000,
        )
      context =
        DiscourseAi::Agents::BotContext.new(
          user: bot_user,
          execution_context: execution,
          subagent_execution_state: state,
        )
      reservation = execution.work_budget.reserve_output(2000)
      tool =
        create_tool(
          script:
            'function invoke() { return llm.generate("First input") + llm.generate("Second input"); }',
        )
      result = tool.runner({}, llm: llm, bot_user: bot_user, context: context).invoke
      expect(result).to eq("Helper outputHelper output")
      expect(requests.map { |body| body["max_tokens"] }).to eq([2000, 1963])
      expect(request).to have_been_requested.twice
      expect(execution.work_budget.used).to eq(74)
      expect(state.remaining_tokens).to eq(1926)
      expect(execution.token_usage_tracker.total).to eq(1074)
      execution.work_budget.release_output(reservation)
      expect(state.remaining_tokens).to eq(3926)
    end

    it "has access to llm truncation tools" do
      script = <<~JS
        function invoke(params) {
          return llm.truncate("Hello World", 1);
        }
      JS

      tool = create_tool(script: script)

      runner = tool.runner({}, llm: llm, bot_user: nil)
      result = runner.invoke

      expect(result).to eq("Hello")
    end

    it "is able to run llm completions" do
      script = <<~JS
        function invoke(params) {
          return llm.generate("question two") + llm.generate(
            { messages: [
              { type: "system", content: "system message" },
              { type: "user", content: "user message" }
            ]}
          );
        }
      JS

      tool = create_tool(script: script)

      result = nil
      prompts = nil
      responses = ["Hello ", "World"]

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_, _, _prompts|
        runner = tool.runner({}, llm: llm, bot_user: nil)
        result = runner.invoke
        prompts = _prompts
      end

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "system message",
          messages: [{ type: :user, content: "user message" }],
        )
      expect(result).to eq("Hello World")
      expect(prompts[0]).to eq("question two")
      expect(prompts[1]).to eq(prompt)
    end

    it "can generate JSON from LLM" do
      tool_record =
        AiTool.create!(
          name: "test_tool",
          tool_name: "test_tool",
          description: "a test tool",
          script: "function invoke() { return llm.generate('test', { json: true }); }",
          summary: "test",
          created_by_id: 1,
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ['{"key": "value"}'],
      ) do |_, _, _, prompt_options|
        runner =
          described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool_record)
        result = runner.invoke
        expect(result).to eq({ "key" => "value" })

        expect(prompt_options.last[:response_format]).to eq({ "type" => "json_object" })
      end
    end
  end
end
