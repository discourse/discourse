# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::OpenAiResponses do
  fab!(:llm_model) { Fabricate(:llm_model, url: "https://api.openai.com/v1/responses") }

  before { enable_current_plugin }

  describe "#translate" do
    it "does not forward a user message name to the responses API" do
      prompt = DiscourseAi::Completions::Prompt.new("You are a bot")
      prompt.push(type: :user, id: "user_1", content: "Hello there")

      dialect = described_class.new(prompt, llm_model)
      translated = dialect.translate

      user_message = translated.find { |msg| msg[:role] == "user" }

      expect(user_message).to be_present
      expect(user_message).not_to have_key(:name)
      expect(user_message[:content]).to eq([{ type: "input_text", text: "user_1: Hello there" }])
    end

    it "preserves encrypted reasoning before tool calls" do
      prompt = DiscourseAi::Completions::Prompt.new("You are a bot")
      prompt.push(type: :user, content: "Please run the tool")
      prompt.push(
        type: :tool_call,
        id: "call_1",
        name: "echo",
        content: { arguments: { string: "hello" } }.to_json,
        provider_data: {
          open_ai_responses: {
            id: "fc_1",
            call_id: "call_1",
          },
        },
        thinking: "summary",
        thinking_provider_info: {
          open_ai_responses: {
            reasoning_id: "rs_1",
            encrypted_content: "ENC",
          },
        },
      )

      dialect = described_class.new(prompt, llm_model)
      translated = dialect.translate

      reasoning_index = translated.index { |msg| msg[:type] == "reasoning" }
      function_call_index = translated.index { |msg| msg[:type] == "function_call" }

      expect(reasoning_index).to be_present
      expect(function_call_index).to be_present
      expect(reasoning_index).to be < function_call_index

      expect(translated[reasoning_index]).to include(
        type: "reasoning",
        id: "rs_1",
        encrypted_content: "ENC",
      )
      expect(translated[function_call_index]).to include(
        type: "function_call",
        id: "fc_1",
        call_id: "call_1",
        name: "echo",
      )
    end
  end
end
