# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::SentimentAgentValidator do
  fab!(:llm_model)

  before { enable_current_plugin }

  describe "#valid_value?" do
    it "allows the default sentiment agent response format" do
      agent =
        Fabricate(
          :ai_agent,
          default_llm_id: llm_model.id,
          response_format: DiscourseAi::Agents::SentimentClassifier.new.response_format,
        )

      expect(described_class.new.valid_value?(agent.id)).to eq(true)
    end

    it "blocks wrapper response formats" do
      agent =
        Fabricate(
          :ai_agent,
          default_llm_id: llm_model.id,
          response_format: [
            { "key" => "sentiment", "type" => "string" },
            { "key" => "score", "type" => "number" },
          ],
        )

      validator = described_class.new

      expect(validator.valid_value?(agent.id)).to eq(false)
      expect(validator.error_message).to include("Expected response format keys")
    end

    it "is wired to the sentiment agent setting" do
      agent =
        Fabricate(
          :ai_agent,
          default_llm_id: llm_model.id,
          response_format: [
            { "key" => "sentiment", "type" => "string" },
            { "key" => "score", "type" => "number" },
          ],
        )

      expect { SiteSetting.ai_sentiment_sentiment_agent = agent.id }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end
end
