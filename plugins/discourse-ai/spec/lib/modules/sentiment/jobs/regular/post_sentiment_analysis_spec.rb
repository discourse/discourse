# frozen_string_literal: true

describe Jobs::PostSentimentAnalysis do
  subject(:job) { described_class.new }

  before { enable_current_plugin }

  describe "#execute" do
    let(:post) { Fabricate(:post) }

    before do
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_emotion_enabled = true
      SiteSetting.ai_sentiment_model_configs =
        "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
    end

    describe "scenarios where we return early without doing anything" do
      it "does nothing when both capabilities are disabled" do
        SiteSetting.ai_sentiment_enabled = false
        SiteSetting.ai_sentiment_emotion_enabled = false

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

    it "classifies using a decision model without enabling workflows" do
      model = Fabricate(:decision_model)
      SiteSetting.enable_discourse_workflows = false
      SiteSetting.ai_sentiment_model_configs = ""
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_sentiment_decision_model = model.id

      DiscourseAi::Decisions.with_canned_answers(
        sentiment: {
          negative: 0.1,
          neutral: 0.2,
          positive: 0.7,
        },
      ) { job.execute({ post_id: post.id }) }

      expect(ClassificationResult.where(target: post).sole).to have_attributes(
        model_used: "discourse-ai/sentiment-decision",
        classification: {
          "negative" => 0.1,
          "neutral" => 0.2,
          "positive" => 0.7,
        },
      )
    end

    [[true, false], [false, true]].each do |sentiment, emotion|
      it "processes only enabled decisions with sentiment=#{sentiment} and emotion=#{emotion}" do
        model = Fabricate(:decision_model)
        SiteSetting.ai_sentiment_enabled = sentiment
        SiteSetting.ai_sentiment_emotion_enabled = emotion
        SiteSetting.ai_sentiment_model_configs = ""
        SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
        SiteSetting.ai_sentiment_emotion_classification_strategy = "decision_model"
        SiteSetting.ai_sentiment_sentiment_decision_model = model.id
        SiteSetting.ai_sentiment_emotion_decision_model = model.id

        DiscourseAi::Decisions.with_canned_answers(
          sentiment: "positive",
          emotion: "joy",
        ) do |canned|
          job.execute(post_id: post.id)

          expect(canned.calls.map { |call| call[:feature_name] }).to eq(
            [sentiment ? "sentiment" : "emotion"],
          )
        end
        expect(ClassificationResult.where(target: post).pluck(:model_used)).to eq(
          [sentiment ? "discourse-ai/sentiment-decision" : "discourse-ai/emotion-decision"],
        )
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
