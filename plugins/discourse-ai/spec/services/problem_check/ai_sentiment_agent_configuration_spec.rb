# frozen_string_literal: true

RSpec.describe ProblemCheck::AiSentimentAgentConfiguration do
  subject(:check) { described_class.new(target) }

  fab!(:llm_model)

  fab!(:ai_agent) do
    Fabricate(
      :ai_agent,
      default_llm_id: llm_model.id,
      response_format: [
        { "key" => "sentiment", "type" => "string" },
        { "key" => "score", "type" => "number" },
      ],
    )
  end

  let(:target) { "sentiment" }

  before do
    enable_current_plugin
    SiteSetting.ai_sentiment_enabled = true
    SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
    SiteSetting.stubs(:ai_sentiment_sentiment_agent).returns(ai_agent.id)
  end

  describe "#call" do
    it "returns a problem when the selected agent has the wrong response format" do
      expect(check).to have_a_problem.with_priority("high").with_target("sentiment")
    end

    it "returns a problem when the selected emotion agent has the wrong response format" do
      emotion_agent =
        Fabricate(
          :ai_agent,
          default_llm_id: llm_model.id,
          response_format: [
            { "key" => "emotion", "type" => "string" },
            { "key" => "score", "type" => "number" },
          ],
        )

      SiteSetting.ai_sentiment_emotion_classification_strategy = "agent"
      SiteSetting.stubs(:ai_sentiment_emotion_agent).returns(emotion_agent.id)

      expect(described_class.new("emotion")).to have_a_problem.with_priority("high").with_target(
        "emotion",
      )
    end

    it "renders the persisted admin notice message" do
      check.run

      message = AdminNotice.find_by!(identifier: "ai_sentiment_agent_configuration").message

      expect(message).to include("Expected response format keys")
      expect(message).to include("sentiment, score")
    end

    it "escapes the agent name in the persisted admin notice message" do
      ai_agent.update!(name: '<a href="https://example.com">bad</a>')
      AiAgent.agent_cache.flush!

      check.run

      message = AdminNotice.find_by!(identifier: "ai_sentiment_agent_configuration").message

      expect(message).to include("&lt;a href")
      expect(message).not_to include('<a href="https://example.com">bad</a>')
    end

    it "returns no problem when the selected agent has the expected response format" do
      ai_agent.update!(
        response_format: DiscourseAi::Agents::SentimentClassifier.new.response_format,
      )

      expect(check).to be_chill_about_it
    end

    it "returns no problem when sentiment classification does not use an agent" do
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "classification_model"

      expect(check).to be_chill_about_it
    end

    it "returns no problem when sentiment is disabled" do
      SiteSetting.ai_sentiment_enabled = false

      expect(check).to be_chill_about_it
    end
  end
end
