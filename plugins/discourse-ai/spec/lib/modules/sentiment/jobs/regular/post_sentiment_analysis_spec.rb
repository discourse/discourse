# frozen_string_literal: true

require_relative "../../../../../support/sentiment_inference_stubs"

describe Jobs::PostSentimentAnalysis do
  subject(:job) { described_class.new }

  before { enable_current_plugin }

  describe "#execute" do
    let(:post) { Fabricate(:post) }

    before do
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_model_configs =
        "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
    end

    describe "scenarios where we return early without doing anything" do
      it "does nothing when ai_sentiment_enabled is disabled" do
        SiteSetting.ai_sentiment_enabled = false

        job.execute({ post_id: post.id })

        expect(ClassificationResult.where(target: post).count).to be_zero
      end

      it "does nothing if there's no arg called post_id" do
        job.execute({})

        expect(ClassificationResult.where(target: post).count).to be_zero
      end

      it "does nothing if no post match the given id" do
        job.execute({ post_id: nil })

        expect(ClassificationResult.where(target: post).count).to be_zero
      end

      it "does nothing if the post content is blank" do
        post.update_columns(raw: "")

        job.execute({ post_id: post.id })

        expect(ClassificationResult.where(target: post).count).to be_zero
      end
    end

    it "successfully classifies the post" do
      expected_analysis = DiscourseAi::Sentiment::PostClassification.new.classifiers.length
      SentimentInferenceStubs.stub_classification(post)

      job.execute({ post_id: post.id })

      expect(ClassificationResult.where(target: post).count).to eq(expected_analysis)
    end
  end
end
