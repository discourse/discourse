# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::PostClassification do
  fab!(:post)
  fab!(:decision_model)
  fab!(:llm_model) { Fabricate(:fake_model, max_prompt_tokens: 32_000) }
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      default_llm: llm_model,
      response_format:
        %w[negative neutral positive].map { |label| { "key" => label, "type" => "number" } },
    )
  end

  before do
    enable_current_plugin
    SiteSetting.ai_sentiment_enabled = true
    SiteSetting.ai_sentiment_emotion_enabled = false
    SiteSetting.ai_sentiment_model_configs = ""
    SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
    SiteSetting.ai_sentiment_sentiment_decision_model = decision_model.id
    SiteSetting.ai_sentiment_sentiment_agent = agent.id
  end

  %i[classify! bulk_classify!].each do |operation|
    describe "##{operation} input budgets" do
      def classify_post(operation)
        target = operation == :classify! ? post : Post.where(id: post.id)
        described_class.new.public_send(operation, target)
      end

      it "preserves a complete post and title for decision models without BERT normalization" do
        post.update!(
          raw: "Opening CASE!\n\n#{"A thoughtful observation. " * 200}\n\nAn UNHAPPY ending.",
        )
        expected = "#{post.topic.title}\n#{post.raw}"

        DiscourseAi::Decisions.with_canned_answers(sentiment: "negative") do |canned|
          classify_post(operation)

          expect(canned.calls.sole[:state]).to eq(expected)
        end
      end

      it "caps decision input at 3000 words while retaining the dedicated 512-token limit" do
        post.update!(
          raw: "Opening CASE!\n\n#{(1..3100).map { |number| "word#{number}" }.join(" ")}",
        )
        full_text = "#{post.topic.title}\n#{post.raw}"
        dedicated_text =
          DiscourseAi::Tokenizer::BertTokenizer.truncate(
            full_text,
            512,
            strict: SiteSetting.ai_strict_token_counting,
          )
        SiteSetting.ai_sentiment_emotion_enabled = true
        SiteSetting.ai_sentiment_emotion_classification_strategy = "classification_model"
        SiteSetting.ai_sentiment_model_configs = [
          {
            classification_type: "emotion",
            model_name: "custom/emotion",
            endpoint: "https://emotion.example.com",
            api_key: "secret",
          },
        ].to_json
        request =
          stub_request(:post, "https://emotion.example.com").with(
            body: { inputs: dedicated_text, truncate: true }.to_json,
          ).to_return(body: [{ label: "neutral", score: 0.9 }].to_json)

        DiscourseAi::Decisions.with_canned_answers(sentiment: "neutral") do |canned|
          classify_post(operation)

          expect(canned.calls.sole[:state].split).to eq(full_text.split.first(3000))
          expect(canned.calls.sole[:state]).to start_with("#{post.topic.title}\nOpening CASE!\n\n")
        end
        expect(request).to have_been_requested.once
        expect(ClassificationResult.where(target: post).pluck(:model_used)).to contain_exactly(
          "discourse-ai/sentiment-decision",
          "custom/emotion",
        )
      end

      it "preserves full agent input below 3000 words" do
        SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
        post.update!(
          raw: "Opening CASE!\n\n#{"A thoughtful observation. " * 200}\n\nAn UNHAPPY ending.",
        )
        expected = "#{post.topic.title}\n#{post.raw}"

        DiscourseAi::Completions::Llm.with_prepared_responses(
          [{ negative: 0.8, neutral: 0.1, positive: 0.1 }],
        ) do |_, _, prompts|
          classify_post(operation)

          expect(prompts.sole.messages.map { |message| message[:content] }).to include(expected)
        end
      end

      it "caps agent input at 3000 words including the title" do
        SiteSetting.ai_sentiment_sentiment_classification_strategy = "agent"
        post.update!(
          raw: "Opening CASE!\n\n#{(1..3100).map { |number| "word#{number}" }.join(" ")}",
        )
        full_text = "#{post.topic.title}\n#{post.raw}"

        DiscourseAi::Completions::Llm.with_prepared_responses(
          [{ negative: 0.1, neutral: 0.8, positive: 0.1 }],
        ) do |_, _, prompts|
          classify_post(operation)

          content = prompts.sole.messages.find { |message| message[:type] == :user }[:content]
          expect(content.split).to eq(full_text.split.first(3000))
          expect(content).to start_with("#{post.topic.title}\nOpening CASE!\n\n")
        end
      end
    end
  end
end
