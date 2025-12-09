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
  end
end
