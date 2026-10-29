# frozen_string_literal: true

RSpec.describe Jobs::SentimentBackfill do
  subject(:job) { described_class.new }

  fab!(:post)
  fab!(:decision_model)

  before do
    enable_current_plugin
    SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
    SiteSetting.ai_sentiment_emotion_classification_strategy = "decision_model"
    SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
    SiteSetting.ai_sentiment_emotion_decision_model = decision_model.id
  end

  it "backfills only enabled decisions with sentiment=false and emotion=false" do
    SiteSetting.ai_sentiment_enabled = (false)
    SiteSetting.ai_sentiment_emotion_enabled = (false)
    enabled_types = []
    enabled_types << "sentiment" if false
    enabled_types << "emotion" if false

    DiscourseAi::Decisions.with_canned_answers(sentiment: "positive", emotion: "joy") do |canned|
      job.execute({})
      job.execute({})

      expect(canned.calls.map { |call| call[:feature_name] }).to match_array(enabled_types)
    end
    expect(ClassificationResult.where(target: post).pluck(:model_used)).to match_array(
      enabled_types.map { |type| "discourse-ai/#{type}-decision" },
    )
  end

  it "backfills only enabled decisions with sentiment=true and emotion=false" do
    SiteSetting.ai_sentiment_enabled = (true)
    SiteSetting.ai_sentiment_emotion_enabled = (false)
    enabled_types = []
    enabled_types << "sentiment" if true
    enabled_types << "emotion" if false

    DiscourseAi::Decisions.with_canned_answers(sentiment: "positive", emotion: "joy") do |canned|
      job.execute({})
      job.execute({})

      expect(canned.calls.map { |call| call[:feature_name] }).to match_array(enabled_types)
    end
    expect(ClassificationResult.where(target: post).pluck(:model_used)).to match_array(
      enabled_types.map { |type| "discourse-ai/#{type}-decision" },
    )
  end

  it "backfills only enabled decisions with sentiment=false and emotion=true" do
    SiteSetting.ai_sentiment_enabled = (false)
    SiteSetting.ai_sentiment_emotion_enabled = (true)
    enabled_types = []
    enabled_types << "sentiment" if false
    enabled_types << "emotion" if true

    DiscourseAi::Decisions.with_canned_answers(sentiment: "positive", emotion: "joy") do |canned|
      job.execute({})
      job.execute({})

      expect(canned.calls.map { |call| call[:feature_name] }).to match_array(enabled_types)
    end
    expect(ClassificationResult.where(target: post).pluck(:model_used)).to match_array(
      enabled_types.map { |type| "discourse-ai/#{type}-decision" },
    )
  end

  it "backfills only enabled decisions with sentiment=true and emotion=true" do
    SiteSetting.ai_sentiment_enabled = (true)
    SiteSetting.ai_sentiment_emotion_enabled = (true)
    enabled_types = []
    enabled_types << "sentiment" if true
    enabled_types << "emotion" if true

    DiscourseAi::Decisions.with_canned_answers(sentiment: "positive", emotion: "joy") do |canned|
      job.execute({})
      job.execute({})

      expect(canned.calls.map { |call| call[:feature_name] }).to match_array(enabled_types)
    end
    expect(ClassificationResult.where(target: post).pluck(:model_used)).to match_array(
      enabled_types.map { |type| "discourse-ai/#{type}-decision" },
    )
  end
end
