# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::ChatGpt do
  fab!(:llm_model) { Fabricate(:llm_model, max_prompt_tokens: 8192) }
  let(:context) { DialectContext.new(described_class, llm_model) }

  before { enable_current_plugin }

  describe "#translate" do
    it "translates a prompt written in our generic format to the ChatGPT format" do
      open_ai_version = [
        { role: "system", content: context.system_insts },
        { role: "user", content: context.simple_user_input },
      ]

      translated = context.system_user_scenario

      expect(translated).to contain_exactly(*open_ai_version)
    end

    it "will retain usernames for unicode usernames, correctly in mixed mode" do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a bot",
          messages: [
            { id: "👻", type: :user, content: "Message1" },
            { type: :model, content: "Ok" },
            { id: "joe", type: :user, content: "Message2" },
          ],
        )

      translated = context.dialect(prompt).translate

      expect(translated).to eq(
        [
          { role: "system", content: "You are a bot" },
          { role: "user", content: "👻: Message1" },
          { role: "assistant", content: "Ok" },
          { role: "user", content: "joe: Message2" },
        ],
      )
    end

    it "translates tool_call and tool messages" do
      expect(context.multi_turn_scenario).to eq(
        [
          { role: "system", content: context.system_insts },
          { role: "user", content: "This is a message by a user", name: "user1" },
          { role: "assistant", content: "I'm a previous bot reply, that's why there's no user" },
          { role: "user", name: "user1", content: "This is a new message by a user" },
          {
            role: "assistant",
            content: nil,
            tool_calls: [
              {
                type: "function",
                function: {
                  name: "get_weather",
                  arguments: { location: "Sydney", unit: "c" }.to_json,
                },
                id: "tool_id",
              },
            ],
          },
          {
            role: "tool",
            content: "I'm a tool result".to_json,
            tool_call_id: "tool_id",
            name: "get_weather",
          },
        ],
      )
    end

    it "trims content if it's getting too long" do
      translated = context.long_user_input_scenario

      expect(translated.last[:role]).to eq("user")
      expect(translated.last[:content].length).to be < context.long_message_text.length
    end

    it "always preserves system message when trimming" do
      # gpt-4 is 8k tokens so last message totally blows everything
      prompt = DiscourseAi::Completions::Prompt.new("You are a bot")
      prompt.push(type: :user, content: "a " * 100)
      prompt.push(type: :model, content: "b " * 100)
      prompt.push(type: :user, content: "zjk " * 10_000)

      translated = context.dialect(prompt).translate

      expect(translated.length).to eq(2)
      expect(translated.first).to eq(content: "You are a bot", role: "system")
      expect(translated.last[:role]).to eq("user")
      expect(translated.last[:content].length).to be < (8000 * 4)
    end
  end

  describe "#tools" do
    it "returns a list of available tools" do
      open_ai_tool_f = {
        function: {
          description: context.tools.first.description,
          name: context.tools.first.name,
          parameters: {
            properties:
              context
                .tools
                .first
                .parameters
                .reduce({}) do |memo, p|
                  memo[p.name] = { description: p.description, type: p.type }

                  memo[p.name][:enum] = p.enum if p.enum

                  memo
                end,
            required: %w[location unit],
            type: "object",
          },
        },
        type: "function",
      }

      expect(context.dialect_tools).to contain_exactly(open_ai_tool_f)
    end
  end
end
