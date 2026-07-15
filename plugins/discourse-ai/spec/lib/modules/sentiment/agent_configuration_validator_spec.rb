# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::AgentConfigurationValidator do
  before { assign_fake_provider_to(:ai_default_llm_model) }

  describe ".validate" do
    it "accepts sentiment agents with the expected response format" do
      ai_agent =
        Fabricate(
          :ai_agent,
          response_format: DiscourseAi::Agents::SentimentClassifier.new.response_format,
        )

      result = described_class.validate(:sentiment, ai_agent.id)

      expect(result).to be_valid
    end

    it "rejects sentiment agents with wrapper response formats" do
      ai_agent =
        Fabricate(
          :ai_agent,
          response_format: [
            { "key" => "sentiment", "type" => "string" },
            { "key" => "score", "type" => "number" },
          ],
        )

      result = described_class.validate(:sentiment, ai_agent.id)

      expect(result).not_to be_valid
      expect(result.problems).to contain_exactly(:invalid_response_format)
    end

    it "uses the classifier emotion labels as the expected keys" do
      result = described_class.validate(:emotion, Fabricate(:ai_agent).id)

      expect(result.expected_keys).to eq(
        DiscourseAi::Sentiment::PostClassification.labels_for(:emotion),
      )
    end

    it "rejects agents without an available LLM" do
      SiteSetting.ai_default_llm_model = ""
      ai_agent = Fabricate(:ai_agent, default_llm_id: nil)
      LlmModel.delete_all

      result = described_class.validate(:sentiment, ai_agent.id)

      expect(result.problems).to include(:missing_llm)
    end
  end
end
