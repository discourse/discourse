# frozen_string_literal: true

require_relative "../../support/sentiment_inference_stubs"

RSpec.describe Jobs::SentimentBackfill do
  before { enable_current_plugin }

  describe "#execute" do
    fab!(:post)

    before do
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_backfill_maximum_posts_per_hour = 100
      SiteSetting.ai_sentiment_model_configs =
        "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
    end

    let(:expected_analysis) { DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values.length }

    it "backfills when settings are correct" do
      SentimentInferenceStubs.stub_classification(post)
      subject.execute({})

      expect(ClassificationResult.where(target: post).count).to eq(expected_analysis)
    end

    it "does nothing when batch size is zero" do
      SiteSetting.ai_sentiment_backfill_maximum_posts_per_hour = 0

      subject.execute({})

      expect(ClassificationResult.count).to be_zero
    end

    it "does nothing when sentiment is disabled" do
      SiteSetting.ai_sentiment_enabled = false

      subject.execute({})

      expect(ClassificationResult.count).to be_zero
    end

    it "respects the ai_sentiment_backfill_post_max_age_days setting" do
      SentimentInferenceStubs.stub_classification(post)
      SiteSetting.ai_sentiment_backfill_post_max_age_days = 80
      post_2 = Fabricate(:post, created_at: 81.days.ago)

      subject.execute({})

      expect(ClassificationResult.where(target: post).count).to eq(expected_analysis)
      expect(ClassificationResult.where(target: post_2).count).to be_zero
    end
  end
end
