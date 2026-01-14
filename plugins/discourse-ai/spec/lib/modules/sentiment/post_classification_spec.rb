# frozen_string_literal: true

require_relative "../../../support/sentiment_inference_stubs"

RSpec.describe DiscourseAi::Sentiment::PostClassification do
  subject(:post_classification) { described_class.new }

  before do
    enable_current_plugin
    SiteSetting.ai_sentiment_enabled = true
    SiteSetting.ai_sentiment_model_configs =
      "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
  end

  def check_classification_for(post)
    result =
      ClassificationResult.find_by(
        model_used: "cardiffnlp/twitter-roberta-base-sentiment-latest",
        target: post,
      )

    expect(result.classification.keys).to contain_exactly("negative", "neutral", "positive")
  end

  describe "#classify!" do
    fab!(:post_1) { Fabricate(:post, post_number: 2) }

    it "does nothing if the post content is blank" do
      post_1.update_columns(raw: "")

      post_classification.classify!(post_1)

      expect(ClassificationResult.where(target: post_1).count).to be_zero
    end

    it "successfully classifies the post" do
      expected_analysis = DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values.length
      SentimentInferenceStubs.stub_classification(post_1)

      post_classification.classify!(post_1)

      expect(ClassificationResult.where(target: post_1).count).to eq(expected_analysis)
    end

    it "classification results must be { emotion => score }" do
      SentimentInferenceStubs.stub_classification(post_1)

      post_classification.classify!(post_1)
      check_classification_for(post_1)
    end

    it "does nothing if there are no classification model" do
      SiteSetting.ai_sentiment_model_configs = ""

      post_classification.classify!(post_1)

      expect(ClassificationResult.where(target: post_1).count).to be_zero
    end

    it "don't reclassify everything when a model config changes" do
      SentimentInferenceStubs.stub_classification(post_1)

      post_classification.classify!(post_1)
      first_classified_at = 2.days.ago
      ClassificationResult.update_all(created_at: first_classified_at)

      current_models = JSON.parse(SiteSetting.ai_sentiment_model_configs)
      current_models << { model_name: "new", endpoint: "https://test.com", api_key: "123" }
      SiteSetting.ai_sentiment_model_configs = current_models.to_json

      SentimentInferenceStubs.stub_classification(post_1)
      post_classification.classify!(post_1.reload)

      new_classifications = ClassificationResult.where("created_at > ?", first_classified_at).count
      expect(new_classifications).to eq(1)
    end
  end

  describe "#classify_bulk!" do
    fab!(:post_1) { Fabricate(:post, post_number: 2) }
    fab!(:post_2) { Fabricate(:post, post_number: 2) }

    it "classifies all given posts" do
      expected_analysis = DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values.length
      SentimentInferenceStubs.stub_classification(post_1)
      SentimentInferenceStubs.stub_classification(post_2)

      post_classification.bulk_classify!(Post.where(id: [post_1.id, post_2.id]))

      expect(ClassificationResult.where(target: post_1).count).to eq(expected_analysis)
      expect(ClassificationResult.where(target: post_2).count).to eq(expected_analysis)
    end

    it "classification results must be { emotion => score }" do
      SentimentInferenceStubs.stub_classification(post_1)
      SentimentInferenceStubs.stub_classification(post_2)

      post_classification.bulk_classify!(Post.where(id: [post_1.id, post_2.id]))

      check_classification_for(post_1)
      check_classification_for(post_2)
    end

    it "does nothing if there are no classification model" do
      SiteSetting.ai_sentiment_model_configs = ""

      post_classification.bulk_classify!(Post.where(id: [post_1.id, post_2.id]))

      expect(ClassificationResult.where(target: post_1).count).to be_zero
      expect(ClassificationResult.where(target: post_2).count).to be_zero
    end

    it "don't reclassify everything when a model config changes" do
      SentimentInferenceStubs.stub_classification(post_1)

      post_classification.bulk_classify!(Post.where(id: [post_1.id]))
      first_classified_at = 2.days.ago
      ClassificationResult.update_all(created_at: first_classified_at)

      current_models = JSON.parse(SiteSetting.ai_sentiment_model_configs)
      current_models << { model_name: "new", endpoint: "https://test.com", api_key: "123" }
      SiteSetting.ai_sentiment_model_configs = current_models.to_json

      SentimentInferenceStubs.stub_classification(post_1)
      post_classification.bulk_classify!(Post.where(id: [post_1.id]))

      new_classifications = ClassificationResult.where("created_at > ?", first_classified_at).count
      expect(new_classifications).to eq(1)
    end
  end

  describe ".backfill_query" do
    it "excludes posts in personal messages" do
      Fabricate(:private_message_post)

      posts = described_class.backfill_query

      expect(posts).to be_empty
    end

    it "includes regular posts only" do
      Fabricate(:small_action)

      posts = described_class.backfill_query

      expect(posts).to be_empty
    end

    it "excludes posts from deleted topics" do
      topic = Fabricate(:topic, deleted_at: 1.hour.ago)
      Fabricate(:post, topic: topic)

      posts = described_class.backfill_query

      expect(posts).to be_empty
    end

    it "includes topics if at least one configured model is missing" do
      classified_post = Fabricate(:post)
      current_models = JSON.parse(SiteSetting.ai_sentiment_model_configs)
      current_models.each do |cm|
        Fabricate(:classification_result, target: classified_post, model_used: cm["model_name"])
      end

      posts = described_class.backfill_query
      expect(posts).not_to include(classified_post)

      current_models << { model_name: "new", endpoint: "htttps://test.com", api_key: "123" }
      SiteSetting.ai_sentiment_model_configs = current_models.to_json

      posts = described_class.backfill_query
      expect(posts).to contain_exactly(classified_post)
    end

    it "excludes deleted posts" do
      Fabricate(:post, deleted_at: 1.hour.ago)

      posts = described_class.backfill_query

      expect(posts).to be_empty
    end

    context "with max_age_days" do
      fab!(:age_post) { Fabricate(:post, created_at: 3.days.ago) }

      it "includes a post when is younger" do
        posts = described_class.backfill_query(max_age_days: 4)

        expect(posts).to contain_exactly(age_post)
      end

      it "excludes posts when it's older" do
        posts = described_class.backfill_query(max_age_days: 2)

        expect(posts).to be_empty
      end
    end

    context "with from_post_id" do
      fab!(:post)

      it "includes post if ID is higher" do
        posts = described_class.backfill_query(from_post_id: post.id - 1)

        expect(posts).to contain_exactly(post)
      end

      it "excludes post if ID is lower" do
        posts = described_class.backfill_query(from_post_id: post.id + 1)

        expect(posts).to be_empty
      end
    end
  end
end
