# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::PostClassification do
  subject(:post_classification) { described_class.new }

  fab!(:decision_model)
  fab!(:post)

  let(:sentiment_scores) { { "negative" => 0.15, "neutral" => 0.2, "positive" => 0.65 } }
  let(:emotion_scores) do
    DiscourseAi::Sentiment::Emotions::LIST.index_with do |label|
      { "joy" => 0.7, "approval" => 0.2, "neutral" => 0.1 }.fetch(label, 0.0)
    end
  end

  before do
    enable_current_plugin
    SiteSetting.ai_sentiment_enabled = true
    SiteSetting.ai_sentiment_emotion_enabled = true
    SiteSetting.ai_sentiment_model_configs = ""
    SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
    SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
  end

  describe "#classify! with decision models" do
    it "stores the exact three-way distribution and requests as the system user" do
      DiscourseAi::Decisions.with_canned_answers(sentiment: sentiment_scores) do |canned|
        post_classification.classify!(post)

        expect(canned.calls).to contain_exactly(
          {
            state: "#{post.topic.title}\n#{post.raw}",
            questions: [
              have_attributes(
                name: "sentiment",
                type: :choice,
                choices: %w[negative neutral positive],
              ),
            ],
            images: [],
            user: Discourse.system_user,
            feature_name: "sentiment",
          },
        )
      end

      expect(ClassificationResult.where(target: post).sole).to have_attributes(
        model_used: "discourse-ai/sentiment-decision",
        classification_type: "sentiment",
        classification: sentiment_scores,
      )
    end

    it "stores all 28 emotion probabilities in a single distribution" do
      SiteSetting.ai_sentiment_emotion_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_emotion_decision_model = decision_model.id

      DiscourseAi::Decisions.with_canned_answers(
        sentiment: sentiment_scores,
        emotion: emotion_scores,
      ) do |canned|
        post_classification.classify!(post)

        expect(canned.calls.map { |call| call[:feature_name] }).to eq(%w[sentiment emotion])
        expect(canned.calls.last[:questions]).to contain_exactly(
          have_attributes(
            name: "emotion",
            type: :choice,
            choices: DiscourseAi::Sentiment::Emotions::LIST,
          ),
        )
      end

      expect(
        ClassificationResult.find_by!(target: post, model_used: "discourse-ai/emotion-decision"),
      ).to have_attributes(classification: emotion_scores, classification_type: "sentiment")
    end

    it "preserves reply content below the word limit without prepending a title" do
      post.update!(post_number: 2, raw: "A technical question.\n\n" * 600)

      DiscourseAi::Decisions.with_canned_answers(sentiment: sentiment_scores) do |canned|
        post_classification.classify!(post)

        expect(canned.calls.sole[:state]).to eq(post.raw)
      end
    end

    it "stores nothing for refusals and retries those posts during backfill" do
      DiscourseAi::Decisions.with_canned_answers(sentiment: :refusal) do
        post_classification.classify!(post)
      end

      expect(ClassificationResult.where(target: post)).to be_empty
      expect(described_class.backfill_query).to contain_exactly(post)
    end

    it "keeps stored results when the selected decision model changes" do
      DiscourseAi::Decisions.with_canned_answers(sentiment: sentiment_scores) do
        post_classification.classify!(post)
      end
      SiteSetting.ai_sentiment_sentiment_decision_model = Fabricate(:decision_model).id

      DiscourseAi::Decisions.with_canned_answers(sentiment: "negative") do |canned|
        post_classification.classify!(post.reload)
        expect(canned.calls).to be_empty
      end

      expect(ClassificationResult.where(target: post).sole.classification).to eq(sentiment_scores)
      expect(described_class.backfill_query).to be_empty
    end

    it "keeps decision and agent backends independent" do
      llm_model = Fabricate(:fake_model)
      agent =
        Fabricate(
          :ai_agent,
          default_llm: llm_model,
          response_format:
            DiscourseAi::Sentiment::Emotions::LIST.map do |label|
              { "key" => label, "type" => "number" }
            end,
        )
      SiteSetting.ai_sentiment_emotion_classification_strategy = "agent"
      SiteSetting.ai_sentiment_emotion_agent = agent.id

      DiscourseAi::Completions::Llm.with_prepared_responses([emotion_scores]) do
        DiscourseAi::Decisions.with_canned_answers(sentiment: sentiment_scores) do
          post_classification.classify!(post)
        end
      end

      expect(ClassificationResult.where(target: post).pluck(:model_used)).to contain_exactly(
        "discourse-ai/sentiment-decision",
        "discourse-ai/emotion-agent",
      )
    end

    it "runs the dedicated backend only for the other selected classification type" do
      SiteSetting.ai_sentiment_model_configs = [
        {
          classification_type: "sentiment",
          model_name: "custom/sentiment",
          endpoint: "srv://excluded.example.com",
          api_key: "secret",
        },
        {
          classification_type: "emotion",
          model_name: "custom/emotion",
          endpoint: "https://emotion.example.com",
          api_key: "secret",
        },
      ].to_json
      request =
        stub_request(:post, "https://emotion.example.com").to_return(
          body: [{ label: "joy", score: 0.7 }].to_json,
        )

      DiscourseAi::Decisions.with_canned_answers(sentiment: sentiment_scores) do
        post_classification.classify!(post)
      end

      expect(request).to have_been_requested.once
      expect(ClassificationResult.where(target: post).pluck(:model_used)).to contain_exactly(
        "discourse-ai/sentiment-decision",
        "custom/emotion",
      )
    end

    it "skips blank and deleted decision models without falling back to dedicated" do
      SiteSetting.ai_sentiment_model_configs = [
        {
          model_name: "custom/dedicated",
          endpoint: "srv://excluded.example.com",
          api_key: "secret",
        },
      ].to_json
      decision_model.destroy!

      [decision_model.id.to_s, ""].each do |model_id|
        SiteSetting.ai_sentiment_sentiment_decision_model = model_id
        post_classification.classify!(post)

        expect(post_classification.classifiers).to be_empty
        expect(described_class.backfill_query).to be_empty
        expect(ClassificationResult.where(target: post)).to be_empty
      end
    end

    it "propagates provider failures without storing a substitute result" do
      request =
        stub_request(:post, decision_model.url).to_return(status: 400, body: "Invalid request")

      expect { post_classification.classify!(post) }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
      )

      expect(request).to have_been_requested.once
      expect(ClassificationResult.where(target: post)).to be_empty
    end

    it "audits and charges each classification type using the default feature cost" do
      decision_model.update!(id: -501)
      SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
      SiteSetting.ai_sentiment_emotion_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_emotion_decision_model = decision_model.id
      Fabricate(
        :decision_model_credit_allocation,
        decision_model: decision_model,
        daily_credits: 1000,
      )
      DecisionModelFeatureCreditCost.create!(
        decision_model: decision_model,
        feature_name: "default",
        credits_per_token: 2,
      )
      request =
        stub_request(:post, decision_model.url).to_return do |http_request|
          type = JSON.parse(http_request.body)["questions"].keys.sole
          scores = type == "sentiment" ? sentiment_scores : emotion_scores
          {
            body: {
              answers: {
                type => {
                  type: "choice",
                  choice: scores.max_by(&:last).first,
                  confidence: 0.99,
                  probabilities: scores,
                },
              },
              usage: {
                input_tokens: 10,
                output_tokens: 2,
              },
            }.to_json,
          }
        end

      post_classification.classify!(post)

      expect(request).to have_been_requested.twice
      expect(AiApiAuditLog.order(:id).pluck(:feature_name, :user_id)).to eq(
        [["sentiment", Discourse.system_user.id], ["emotion", Discourse.system_user.id]],
      )
      expect(DecisionModelCreditDailyUsage.usage_for_date(decision_model.id, Date.current)).to eq(
        48,
      )
      expect(
        ClassificationResult.find_by!(
          target: post,
          model_used: "discourse-ai/sentiment-decision",
        ).classification,
      ).to eq(sentiment_scores)
      expect(
        ClassificationResult.find_by!(
          target: post,
          model_used: "discourse-ai/emotion-decision",
        ).classification,
      ).to eq(emotion_scores)
    end

    it "propagates credit limits without storing results" do
      decision_model.update!(id: -502)
      SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
      Fabricate(
        :decision_model_credit_allocation,
        decision_model: decision_model,
        daily_credits: 10,
      )
      DecisionModelCreditDailyUsage.increment_usage!(decision_model, 10)

      expect { post_classification.classify!(post) }.to raise_error(
        DiscourseAi::Decisions::CreditLimitExceeded,
      )
      expect(ClassificationResult.where(target: post)).to be_empty
    end
  end

  describe "#classifiers with decision models" do
    it "excludes all dedicated configs when neither type selects the dedicated strategy" do
      SiteSetting.ai_sentiment_emotion_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_model_configs = [
        { model_name: "unknown/one", endpoint: "srv://excluded.example.com", api_key: "secret" },
        { model_name: "unknown/two", endpoint: "srv://excluded.example.com", api_key: "secret" },
      ].to_json

      expect(post_classification.classifiers.map { |classifier| classifier[:model_name] }).to eq(
        ["discourse-ai/sentiment-decision"],
      )
    end

    it "preserves multiple untyped dedicated configs while one type still selects dedicated" do
      SiteSetting.ai_sentiment_model_configs = [
        { model_name: "unknown/one", endpoint: "https://one.example.com", api_key: "secret" },
        { model_name: "unknown/two", endpoint: "https://two.example.com", api_key: "secret" },
      ].to_json

      expect(
        post_classification.classifiers.map { |classifier| classifier[:model_name] },
      ).to contain_exactly("unknown/one", "unknown/two", "discourse-ai/sentiment-decision")
    end
  end

  describe "#bulk_classify! with decision models" do
    it "stores successful distributions while leaving refused classifications missing" do
      SiteSetting.ai_sentiment_emotion_classification_strategy = "decision_model"
      SiteSetting.ai_sentiment_emotion_decision_model = decision_model.id

      DiscourseAi::Decisions.with_canned_answers(sentiment: sentiment_scores, emotion: :refusal) do
        post_classification.bulk_classify!(Post.where(id: post.id))
      end

      expect(ClassificationResult.where(target: post).sole).to have_attributes(
        model_used: "discourse-ai/sentiment-decision",
        classification: sentiment_scores,
      )
      expect(described_class.backfill_query).to contain_exactly(post)
    end
  end
end
