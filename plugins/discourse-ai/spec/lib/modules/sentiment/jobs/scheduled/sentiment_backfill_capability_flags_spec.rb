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

  shared_examples "backfilling enabled sentiment capabilities" do |sentiment_enabled:, emotion_enabled:, expected_types:|
    it "runs each enabled decision once across repeated backfills" do
      SiteSetting.ai_sentiment_enabled = sentiment_enabled
      SiteSetting.ai_sentiment_emotion_enabled = emotion_enabled

      DiscourseAi::Decisions.with_canned_answers(sentiment: "positive", emotion: "joy") do |canned|
        job.execute({})
        job.execute({})

        expect(canned.calls.map { |call| call[:feature_name] }).to match_array(expected_types)
      end
      expect(ClassificationResult.where(target: post).pluck(:model_used)).to match_array(
        expected_types.map { |type| "discourse-ai/#{type}-decision" },
      )
    end
  end

  context "with both capabilities disabled" do
    include_examples "backfilling enabled sentiment capabilities",
                     sentiment_enabled: false,
                     emotion_enabled: false,
                     expected_types: []
  end

  context "with only sentiment enabled" do
    include_examples "backfilling enabled sentiment capabilities",
                     sentiment_enabled: true,
                     emotion_enabled: false,
                     expected_types: %w[sentiment]
  end

  context "with only emotion enabled" do
    include_examples "backfilling enabled sentiment capabilities",
                     sentiment_enabled: false,
                     emotion_enabled: true,
                     expected_types: %w[emotion]
  end

  context "with both capabilities enabled" do
    include_examples "backfilling enabled sentiment capabilities",
                     sentiment_enabled: true,
                     emotion_enabled: true,
                     expected_types: %w[sentiment emotion]
  end
end
