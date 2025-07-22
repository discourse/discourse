# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::Ollama do
  fab!(:model) { Fabricate(:ollama_model) }
  let(:context) { DialectContext.new(described_class, model) }
  let(:dialect_class) { DiscourseAi::Completions::Dialects::Dialect.dialect_for(model) }

  before { enable_current_plugin }

  describe "#translate" do
    context "when native tool support is enabled" do
      it "translates a prompt written in our generic format to the Ollama format" do
        ollama_version = [
          { role: "system", content: context.system_insts },
          { role: "user", content: context.simple_user_input },
        ]

        translated = context.system_user_scenario

        expect(translated).to eq(ollama_version)
      end
    end

    context "when native tool support is disabled - XML tools" do
      it "includes the instructions in the system message" do
        allow(model).to receive(:lookup_custom_param).with("enable_native_tool").and_return(false)

        DiscourseAi::Completions::Dialects::XmlTools
          .any_instance
          .stubs(:instructions)
          .returns("Instructions")

        ollama_version = [
          { role: "system", content: "#{context.system_insts}\n\nInstructions" },
          { role: "user", content: context.simple_user_input },
        ]

        translated = context.system_user_scenario

        expect(translated).to eq(ollama_version)
      end
    end

    it "trims content if it's getting too long" do
      model.max_prompt_tokens = 5000
      translated = context.long_user_input_scenario

      expect(translated.last[:role]).to eq("user")
      expect(translated.last[:content].length).to be < context.long_message_text.length
    end
  end

  describe "#max_prompt_tokens" do
    it "returns the max_prompt_tokens from the llm_model" do
      model.max_prompt_tokens = 10_000
      expect(context.dialect(nil).max_prompt_tokens).to eq(10_000)
    end
  end

  describe "#tools" do
    context "when native tools are enabled" do
      it "returns the translated tools from the OllamaTools class" do
        model.update!(provider_params: { enable_native_tool: true })

        tool = { name: "noop", description: "do nothing" }
        messages = [
          { type: :user, content: "echo away" },
          { type: :tool_call, content: "{}", name: "noop" },
          { type: :tool, content: "{}", name: "noop" },
        ]
        prompt = DiscourseAi::Completions::Prompt.new("a bot", tools: [tool], messages: messages)
        dialect = dialect_class.new(prompt, model)

        expected = [
          { role: "system", content: "a bot" },
          { role: "user", content: "echo away" },
          {
            role: "assistant",
            content: nil,
            tool_calls: [{ type: "function", function: { name: "noop" } }],
          },
          { role: "tool", content: "{}", name: "noop" },
        ]
        expect(dialect.translate).to eq(expected)
      end
    end

    context "when native tools are disabled" do
      it "returns the translated tools from the XmlTools class" do
        model.update!(provider_params: { enable_native_tool: false })

        tool = { name: "noop", description: "do nothing" }
        messages = [
          { type: :user, content: "echo away" },
          { type: :tool_call, content: "{}", name: "noop" },
          { type: :tool, content: "{}", name: "noop" },
        ]
        prompt = DiscourseAi::Completions::Prompt.new("a bot", tools: [tool], messages: messages)
        dialect = dialect_class.new(prompt, model)

        expected = %w[system user assistant user]
        roles = dialect.translate.map { |x| x[:role] }

        # notice, no tool role
        expect(roles).to eq(expected)
      end
    end
  end
end
