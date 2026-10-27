# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::PostClassification do
  fab!(:post)
  fab!(:decision_model)
  fab!(:llm_model, :fake_model)
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      default_llm: llm_model,
      response_format:
        %w[negative neutral positive joy].map { |label| { "key" => label, "type" => "number" } },
    )
  end

  before do
    enable_current_plugin
    DiscourseAi::Utils::DnsSrv.stubs(:lookup).raises(RuntimeError, "Unexpected SRV lookup")
  end

  %w[classification_model agent decision_model].each do |backend|
    describe "independent enable flags with #{backend}" do
      before do
        SiteSetting.ai_sentiment_sentiment_classification_strategy = backend
        SiteSetting.ai_sentiment_emotion_classification_strategy = backend
        SiteSetting.ai_sentiment_sentiment_agent = agent.id
        SiteSetting.ai_sentiment_emotion_agent = agent.id
        SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
        SiteSetting.ai_sentiment_emotion_decision_model = decision_model.id
        SiteSetting.ai_sentiment_model_configs =
          %w[sentiment emotion]
            .map do |type|
              {
                classification_type: type,
                model_name: "custom/#{type}",
                endpoint: "https://#{type}.example.com",
                api_key: "secret",
              }
            end
            .to_json
      end

      [[false, false], [true, false], [false, true], [true, true]].each do |sentiment, emotion|
        it "runs only enabled capabilities with sentiment=#{sentiment} and emotion=#{emotion}" do
          SiteSetting.ai_sentiment_enabled = sentiment
          SiteSetting.ai_sentiment_emotion_enabled = emotion
          enabled_types = []
          enabled_types << "sentiment" if sentiment
          enabled_types << "emotion" if emotion
          model_names = enabled_types.map { |type| described_class.active_model_name_for(type) }
          classifier = described_class.new

          expect(described_class.enabled_for?(:sentiment)).to eq(sentiment)
          expect(described_class.enabled_for?("emotion")).to eq(emotion)
          expect(described_class.any_enabled?).to eq(sentiment || emotion)
          expect(described_class.active_classifier_names).to match_array(model_names)
          expect(classifier.has_classifiers?).to eq(sentiment || emotion)
          expect(described_class.backfill_query).to match_array(enabled_types.empty? ? [] : [post])
          %w[sentiment emotion].each do |type|
            expect(described_class.classifier_summary_for(type)[:ready]).to eq(true)
          end

          SentimentInferenceStubs.stub_classification(post)
          DiscourseAi::Completions::Llm.with_prepared_responses(
            [{ negative: 0.1, neutral: 0.2, positive: 0.7, joy: 0.7 }] * 2,
          ) do
            DiscourseAi::Decisions.with_canned_answers(sentiment: "positive", emotion: "joy") do
              classifier.classify!(post)
              classifier.bulk_classify!(Post.where(id: post.id))
            end
          end

          expect(ClassificationResult.where(target: post).pluck(:model_used)).to match_array(
            model_names,
          )
          expect(described_class.backfill_query).to be_empty
        end
      end
    end
  end

  describe "dedicated capability attribution" do
    before do
      SiteSetting.ai_sentiment_model_configs = [
        {
          model_name: DiscourseAi::Sentiment::Constants::SENTIMENT_MODEL,
          endpoint: "srv://disabled-sentiment.example.com",
          api_key: "secret",
        },
        {
          model_name: DiscourseAi::Sentiment::Constants::EMOTION_MODEL,
          endpoint: "https://emotion.example.com",
          api_key: "secret",
        },
        {
          model_name: "unknown/one",
          endpoint: "srv://ambiguous-one.example.com",
          api_key: "secret",
        },
        {
          model_name: "unknown/two",
          endpoint: "srv://ambiguous-two.example.com",
          api_key: "secret",
        },
      ].to_json
    end

    it "excludes default-named sentiment and ambiguous configs before resolving disabled endpoints" do
      SiteSetting.ai_sentiment_enabled = false
      SiteSetting.ai_sentiment_emotion_enabled = true

      expect(described_class.active_classifier_names).to eq(
        [DiscourseAi::Sentiment::Constants::EMOTION_MODEL],
      )
    end

    it "excludes a lone untyped custom config when sentiment is disabled" do
      SiteSetting.ai_sentiment_enabled = false
      SiteSetting.ai_sentiment_emotion_enabled = true
      SiteSetting.ai_sentiment_model_configs = [
        { model_name: "unknown/only", endpoint: "srv://disabled.example.com", api_key: "secret" },
      ].to_json

      expect(described_class.new.classifiers).to be_empty
      expect(described_class.backfill_query).to be_empty
    end
  end

  describe ".backfill_query with disabled capabilities" do
    before do
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_emotion_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
      SiteSetting.ai_sentiment_emotion_decision_model = decision_model.id
      Fabricate(
        :sentiment_classification,
        target: post,
        model_used: "discourse-ai/sentiment-decision",
      )
    end

    it "selects missing results only for enabled capabilities" do
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_emotion_enabled = false
      expect(described_class.backfill_query).to be_empty

      SiteSetting.ai_sentiment_emotion_enabled = true
      expect(described_class.backfill_query).to contain_exactly(post)

      SiteSetting.ai_sentiment_enabled = false
      expect(described_class.backfill_query).to contain_exactly(post)

      SiteSetting.ai_sentiment_emotion_enabled = false
      expect(described_class.backfill_query).to be_empty
    end
  end
end
