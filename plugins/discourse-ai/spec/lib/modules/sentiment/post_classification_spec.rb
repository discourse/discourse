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

  def agent_for(response_format, llm_model)
    Fabricate(
      :ai_agent,
      default_llm: llm_model,
      response_format: response_format,
      system_prompt: "Classify this post",
    )
  end

  describe ".active_model_name_for" do
    it "uses an explicitly typed custom sentiment classifier for read paths" do
      SiteSetting.ai_sentiment_model_configs = [
        {
          classification_type: "sentiment",
          model_name: "custom/sentiment-model",
          endpoint: "https://sentiment.example.com",
          api_key: "123",
        },
      ].to_json

      expect(described_class.active_model_name_for(:sentiment)).to eq("custom/sentiment-model")
    end

    it "uses a single legacy untyped custom classifier for sentiment read paths" do
      SiteSetting.ai_sentiment_model_configs = [
        {
          model_name: "custom/classifier",
          endpoint: "https://sentiment.example.com",
          api_key: "123",
        },
      ].to_json

      expect(described_class.active_model_name_for(:sentiment)).to eq("custom/classifier")
    end

    it "prefers the default emotion classifier when multiple legacy emotion classifiers are configured" do
      expect(described_class.active_model_name_for(:emotion)).to eq(
        DiscourseAi::Sentiment::Constants::EMOTION_MODEL,
      )
    end
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

    it "classifies sentiment through a configured agent" do
      llm_model = Fabricate(:fake_model)
      ai_agent =
        agent_for(
          %w[negative neutral positive].map { |label| { "key" => label, "type" => "number" } },
          llm_model,
        )
      SiteSetting.ai_sentiment_model_configs = ""
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
      SiteSetting.ai_sentiment_sentiment_agent = ai_agent.id

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [{ negative: 0.1, neutral: 0.2, positive: 0.7 }],
      ) { post_classification.classify!(post_1) }

      result =
        ClassificationResult.find_by!(
          model_used: DiscourseAi::Sentiment::Constants::SENTIMENT_AGENT_MODEL,
          target: post_1,
        )

      expect(result.classification).to eq("negative" => 0.1, "neutral" => 0.2, "positive" => 0.7)
    end

    it "classifies emotion through a configured agent" do
      llm_model = Fabricate(:fake_model)
      ai_agent =
        agent_for(
          DiscourseAi::Sentiment::Emotions::LIST.map do |label|
            { "key" => label, "type" => "number" }
          end,
          llm_model,
        )
      SiteSetting.ai_sentiment_model_configs = ""
      SiteSetting.ai_sentiment_emotion_classification_strategy = "agent"
      SiteSetting.ai_sentiment_emotion_agent = ai_agent.id

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [{ anger: 0.7, joy: 0.2, neutral: 0.1 }],
      ) { post_classification.classify!(post_1) }

      result =
        ClassificationResult.find_by!(
          model_used: DiscourseAi::Sentiment::Constants::EMOTION_AGENT_MODEL,
          target: post_1,
        )

      expect(result.classification.keys).to contain_exactly(*DiscourseAi::Sentiment::Emotions::LIST)
      expect(result.classification.slice("anger", "joy", "neutral")).to eq(
        "anger" => 0.7,
        "joy" => 0.2,
        "neutral" => 0.1,
      )
    end

    it "skips a lone legacy untyped sentiment config when sentiment strategy is agent" do
      llm_model = Fabricate(:fake_model)
      ai_agent =
        agent_for(
          %w[negative neutral positive].map { |label| { "key" => label, "type" => "number" } },
          llm_model,
        )
      SiteSetting.ai_sentiment_model_configs = [
        { model_name: "custom/legacy", endpoint: "https://legacy.example.com", api_key: "123" },
      ].to_json
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
      SiteSetting.ai_sentiment_sentiment_agent = ai_agent.id

      model_names = post_classification.classifiers.map { |c| c[:model_name] }
      expect(model_names).to include(DiscourseAi::Sentiment::Constants::SENTIMENT_AGENT_MODEL)
      expect(model_names).not_to include("custom/legacy")
    end

    it "skips storing when the agent returns no usable classification" do
      llm_model = Fabricate(:fake_model)
      ai_agent =
        agent_for(
          %w[negative neutral positive].map { |label| { "key" => label, "type" => "number" } },
          llm_model,
        )
      SiteSetting.ai_sentiment_model_configs = ""
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
      SiteSetting.ai_sentiment_sentiment_agent = ai_agent.id

      DiscourseAi::Completions::Llm.with_prepared_responses(["not json"]) do
        post_classification.classify!(post_1)
      end

      expect(
        ClassificationResult.where(
          model_used: DiscourseAi::Sentiment::Constants::SENTIMENT_AGENT_MODEL,
          target: post_1,
        ),
      ).to be_empty
    end

    it "falls back to the newest LLM model when the configured agent does not set a default LLM" do
      Fabricate(:fake_model, name: "older-model", created_at: 1.day.ago)
      llm_model = Fabricate(:fake_model, name: "newer-model")
      ai_agent =
        Fabricate(
          :ai_agent,
          default_llm: nil,
          response_format:
            %w[negative neutral positive].map { |label| { "key" => label, "type" => "number" } },
          system_prompt: "Classify this post",
        )
      SiteSetting.ai_default_llm_model = ""
      SiteSetting.ai_sentiment_model_configs = ""
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
      SiteSetting.ai_sentiment_sentiment_agent = ai_agent.id

      classifier =
        post_classification.send(
          :agent_classifier,
          :sentiment,
          ai_agent.id,
          DiscourseAi::Sentiment::Constants::SENTIMENT_AGENT_MODEL,
        )

      expect(classifier[:model]).to eq(llm_model)
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

    it "does not reclassify agent results when the agent LLM changes" do
      llm_model = Fabricate(:fake_model)
      ai_agent =
        agent_for(
          %w[negative neutral positive].map { |label| { "key" => label, "type" => "number" } },
          llm_model,
        )
      SiteSetting.ai_sentiment_model_configs = ""
      SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
      SiteSetting.ai_sentiment_emotion_classification_strategy = "agent"
      SiteSetting.ai_sentiment_sentiment_agent = ai_agent.id
      SiteSetting.ai_sentiment_emotion_agent = "0"

      classified_post = Fabricate(:post)
      Fabricate(
        :classification_result,
        target: classified_post,
        model_used: DiscourseAi::Sentiment::Constants::SENTIMENT_AGENT_MODEL,
      )

      ai_agent.update!(default_llm: Fabricate(:fake_model, name: "new-model"))

      posts = described_class.backfill_query
      expect(posts).to be_empty
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
