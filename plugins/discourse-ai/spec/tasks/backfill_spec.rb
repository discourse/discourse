# frozen_string_literal: true

require_relative "../support/sentiment_inference_stubs"

RSpec.describe "ai:sentiment:backfill" do
  before do
    enable_current_plugin
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

  before do
    SiteSetting.ai_sentiment_model_configs =
      "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
  end

  it "does nothing if the topic is soft-deleted" do
    target = Fabricate(:post)
    SentimentInferenceStubs.stub_classification(target)
    target.topic.trash!

    Rake::Task["ai:sentiment:backfill"].invoke

    expect(ClassificationResult.count).to be_zero
  end
end
