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

    it "captures a tool-backed topic gist without structured output" do
      custom_agent =
        Fabricate(:ai_agent, response_format: [{ "key" => "fragile", "type" => "string" }])
      SiteSetting.ai_summary_gists_agent = custom_agent.id
      gist_summarizer = DiscourseAi::Summarization.topic_gist(topic, locale: "ja")
      expect(gist_summarizer.bot.agent.response_format).to be_nil
      expect(gist_summarizer.bot.returns_json?).to eq(false)
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          id: "call_1",
          name: "set_topic_summary",
          parameters: {
            summary: "日本語の要約",
          },
        )

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do |spy|
          gist_summarizer
            .summarize(user)
            .tap do
              expect(spy.completions).to eq(1)
              expect(spy.model_params[:response_format]).to be_nil
            end
        end

      expect(result).to have_attributes(summarized_text: "日本語の要約", locale: "ja")
    end

    it "does not persist a gist when the model omits the summary tool" do
      gist_summarizer = DiscourseAi::Summarization.topic_gist(topic, locale: "ja")

      expect do
        DiscourseAi::Completions::Llm.with_prepared_responses(["plain text"]) do
          gist_summarizer.summarize(user)
        end
      end.to raise_error(DiscourseAi::Summarization::FoldContent::MissingToolOutput)

      expect(AiSummary.gist.where(target: topic, locale: "ja")).to be_empty
    end
  end

  describe "#existing_summary" do
    it "finds a gist stored under an equivalent regional locale" do
      existing_gist =
        Fabricate(
          :topic_ai_gist,
          target: topic,
          locale: "pt",
          highest_target_number: topic.highest_post_number,
          original_content_sha: AiSummary.build_sha("1"),
        )
      regional_summarizer = DiscourseAi::Summarization.topic_gist(topic, locale: "pt_BR")

      expect(regional_summarizer.existing_summary).to eq(existing_gist)
    end

    it "finds and deletes a complete summary stored under an equivalent regional locale" do
      existing_summary =
        Fabricate(
          :ai_summary,
          target: topic,
          locale: "pt",
          highest_target_number: topic.highest_post_number,
          original_content_sha: AiSummary.build_sha("1"),
        )
      regional_summarizer = DiscourseAi::Summarization.topic_summary(topic, locale: "pt_BR")

      expect(regional_summarizer.existing_summary).to eq(existing_summary)

      regional_summarizer.delete_cached_summaries!
      expect(AiSummary.find_by(id: existing_summary.id)).to be_nil
    end

    context "when a summary already exists" do
      fab!(:ai_summary) do
        Fabricate(
          :ai_summary,
          target: topic,
          locale: SiteSetting.default_locale,
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

  describe "#truncate" do
    it "preserves grapheme clusters for multi-codepoint emoji sequences" do
      # Starts with scales emoji (⚖️ = U+2696 + U+FE0F) so we can catch any split between code points.
      sample_text = "⚖️🧩"

      item = summarizer.truncate({ text: sample_text.dup })

      expect(item[:text]).to start_with("⚖️ ")
      expect(item[:text]).to include("🧩")
      expect(item[:text]).not_to start_with("⚖ ️")
    end

    it "keeps the second half of the text in the original order" do
      sample_text = "abcdefgh"

      item = summarizer.truncate({ text: sample_text.dup })

      expect(item[:text]).to include("efgh")
      expect(item[:text]).not_to include("hgfe")
    end
  end
end
