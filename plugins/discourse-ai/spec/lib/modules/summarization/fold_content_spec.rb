# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::FoldContent do
  subject(:summarizer) { DiscourseAi::Summarization.topic_summary(topic) }

  let!(:llm_model) { assign_fake_provider_to(:ai_default_llm_model) }

  fab!(:topic) { Fabricate(:topic, highest_post_number: 2) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1, raw: "This is a text") }

  before do
    enable_current_plugin
    SiteSetting.ai_summarization_enabled = true
  end

  describe "#summarize" do
    before do
      # Make sure each content fits in a single chunk.
      # 700 is the number of tokens reserved for the prompt.
      model_tokens =
        700 +
          DiscourseAi::Tokenizer::OpenAiTokenizer.size(
            "(1 #{post_1.user.username_lower} said: This is a text ",
          ) + 3

      llm_model.update!(max_prompt_tokens: model_tokens)
    end

    let(:summary) { "this is a summary" }

    fab!(:user)

    it "summarizes the content" do
      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do |spy|
          summarizer.summarize(user).tap { expect(spy.completions).to eq(1) }
        end

      expect(result.summarized_text).to eq(summary)
    end
  end

  describe "#existing_summary" do
    context "when a summary already exists" do
      fab!(:ai_summary) do
        Fabricate(
          :ai_summary,
          target: topic,
          highest_target_number: topic.highest_post_number,
          original_content_sha: AiSummary.build_sha("1"),
        )
      end

      it "doesn't mark it as outdated" do
        expect(summarizer.existing_summary.outdated).to eq(false)
      end

      context "when it's outdated because there are new targets" do
        before { Fabricate(:post, topic: topic, post_number: 2, raw: "This is a text") }

        it "marks it as outdated" do
          expect(summarizer.existing_summary.outdated).to eq(true)
        end
      end

      context "when it's outdated because existing content changes" do
        it "marks it as outdated" do
          ai_summary.update!(updated_at: 20.minutes.ago)
          post_1.update!(last_version_at: 5.minutes.ago)

          expect(summarizer.existing_summary.outdated).to eq(true)
        end
      end
    end
  end
end
