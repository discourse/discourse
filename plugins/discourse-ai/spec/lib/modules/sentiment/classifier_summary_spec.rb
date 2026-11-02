# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::PostClassification do
  before do
    enable_current_plugin
    DiscourseAi::Utils::DnsSrv.stubs(:lookup).raises(RuntimeError, "Unexpected SRV lookup")
  end

  describe ".classifier_summary_for" do
    fab!(:older_model) { Fabricate(:fake_model, name: "older") }
    fab!(:latest_model) { Fabricate(:fake_model, name: "latest") }
    fab!(:agent) { Fabricate(:ai_agent, enabled: false, default_llm: older_model) }

    it "selects the agent's default model even when the agent and module are disabled" do
      SiteSetting.ai_sentiment_enabled = false
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
      SiteSetting.ai_sentiment_sentiment_agent = agent.id
      SiteSetting.ai_default_llm_model = latest_model.id

      expect(described_class.classifier_summary_for(:sentiment)).to eq(
        backend: "agent",
        ready: true,
        agent_ids: [agent.id],
        llm_models: [older_model],
      )
      expect(described_class.new.classifiers).to be_empty
    end

    it "matches runtime's site-default and latest-model fallbacks" do
      SiteSetting.ai_sentiment_emotion_enabled = true
      agent.update!(default_llm: nil)
      SiteSetting.ai_sentiment_emotion_classification_strategy = "agent"
      SiteSetting.ai_sentiment_emotion_agent = agent.id
      SiteSetting.ai_default_llm_model = older_model.id

      expect(described_class.classifier_summary_for("emotion")[:llm_models]).to eq([older_model])
      expect(described_class.new.classifiers.sole[:model]).to eq(older_model)

      SiteSetting.ai_default_llm_model = ""

      expect(described_class.classifier_summary_for(:emotion)[:llm_models]).to eq([latest_model])
      expect(described_class.new.classifiers.sole[:model]).to eq(latest_model)
    end

    it "reports an unresolved effective LLM as not ready without substituting the latest model" do
      agent.update!(default_llm: nil)
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
      SiteSetting.ai_sentiment_sentiment_agent = agent.id
      SiteSetting.ai_default_llm_model = older_model.id
      older_model.destroy!

      expect(described_class.classifier_summary_for(:sentiment)).to eq(
        backend: "agent",
        ready: false,
        agent_ids: [agent.id],
        llm_models: [],
      )
      expect(described_class.new.classifiers).to be_empty
    end

    it "reports an unavailable agent as not ready" do
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
      SiteSetting.ai_sentiment_sentiment_agent = agent.id
      agent.destroy!

      expect(described_class.classifier_summary_for(:sentiment)).to eq(
        backend: "agent",
        ready: false,
        agent_ids: [],
        llm_models: [],
      )
      expect(described_class.new.classifiers).to be_empty
    end

    it "exposes only decision model identity without resolving its SRV endpoint or credentials" do
      model =
        Fabricate(
          :decision_model,
          url: "srv://decision.example.com",
          custom_headers: [{ name: "X-Secret", value: "private" }],
        )
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_sentiment_decision_model = model.id

      expect(described_class.classifier_summary_for(:sentiment)).to eq(
        backend: "decision_model",
        ready: true,
        decision_model: {
          id: model.id,
          display_name: model.display_name,
        },
      )
      expect(described_class.new.classifiers.sole[:model]).to eq(model)
    end

    it "reports blank and deleted decision models as not ready" do
      model = Fabricate(:decision_model)
      model.destroy!
      SiteSetting.ai_sentiment_emotion_classification_strategy = "decision_model"

      ["", model.id.to_s].each do |model_id|
        SiteSetting.ai_sentiment_emotion_decision_model = model_id
        expect(described_class.classifier_summary_for(:emotion)).to eq(
          backend: "decision_model",
          ready: false,
          decision_model: nil,
        )
        expect(described_class.new.classifiers).to be_empty
      end
    end

    it "exposes only the selected dedicated name without resolving SRV or exposing secrets" do
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_model_configs = [
        {
          classification_type: "sentiment",
          model_name: "private/sentiment",
          endpoint: "srv://sentiment.example.com",
          api_key: "private-key",
        },
      ].to_json

      expect(described_class.classifier_summary_for(:sentiment)).to eq(
        backend: "classification_model",
        ready: true,
        classification_model: {
          model_name: "private/sentiment",
        },
      )
    end

    it "matches the single untyped custom dedicated fallback" do
      SiteSetting.ai_sentiment_model_configs = [
        {
          model_name: "private/custom",
          endpoint: "https://sentiment.example.com",
          api_key: "private-key",
        },
      ].to_json

      expect(described_class.classifier_summary_for(:sentiment)).to eq(
        backend: "classification_model",
        ready: true,
        classification_model: {
          model_name: "private/custom",
        },
      )
      expect(described_class.new.classifiers).to be_empty
    end

    it "reports missing or blank dedicated endpoints as not ready" do
      expect(described_class.classifier_summary_for(:sentiment)).to eq(
        backend: "classification_model",
        ready: false,
        classification_model: {
          model_name: DiscourseAi::Sentiment::Constants::SENTIMENT_MODEL,
        },
      )
      SiteSetting.ai_sentiment_model_configs = [
        {
          classification_type: "emotion",
          model_name: "private/emotion",
          endpoint: "",
          api_key: "private-key",
        },
      ].to_json

      expect(described_class.classifier_summary_for(:emotion)).to eq(
        backend: "classification_model",
        ready: false,
        classification_model: {
          model_name: "private/emotion",
        },
      )
    end
  end
end
