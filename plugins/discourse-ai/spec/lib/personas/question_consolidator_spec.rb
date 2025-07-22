# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::QuestionConsolidator do
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{Fabricate(:fake_model).id}") }
  let(:fake_endpoint) { DiscourseAi::Completions::Endpoints::Fake }

  fab!(:user)

  before { enable_current_plugin }

  describe ".consolidate_question" do
    it "properly picks all the right messages and consolidates" do
      messages = [
        { type: :user, content: "What is the capital of France?" },
        { type: :tool_call, content: "search:google", id: "123" },
        { type: :tool, content: "some results from google", id: "123" },
        { type: :model, content: "Paris" },
        { type: :user, content: "What about Germany?" },
      ]

      result = described_class.consolidate_question(llm, messages, user)
      expect(result).to eq(fake_endpoint.fake_content)

      call = fake_endpoint.last_call

      prompt = call[:dialect].prompt
      expect(prompt.messages.length).to eq(2)
      content = prompt.messages[1][:content]
      expect(content).to include("Germany")
      expect(content).to include("France")
      expect(content).to include("Paris")
      expect(content).not_to include("google")
    end
  end
end
