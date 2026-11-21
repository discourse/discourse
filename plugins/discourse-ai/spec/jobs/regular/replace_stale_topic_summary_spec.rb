# frozen_string_literal: true

RSpec.describe Jobs::ReplaceStaleTopicSummary do
  subject(:job) { described_class.new }

  fab!(:topic)
  fab!(:post_1) { Fabricate(:post, topic:, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic:, post_number: 2) }

  let(:replacement) { "A fresh take" }
  let(:tool_call) do
    DiscourseAi::Completions::ToolCall.new(
      id: "call_1",
      name: "set_topic_summary",
      parameters: {
        summary: replacement,
      },
    )
  end

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summary_gists_enabled = true
  end

  describe "#execute" do
    context "with a stale gist" do
      fab!(:gist) { Fabricate(:topic_ai_gist, target: topic, locale: "en") }
      fab!(:other_locale_gist) { Fabricate(:topic_ai_gist, target: topic, locale: "ja") }
      fab!(:summary) { Fabricate(:ai_summary, target: topic, locale: "en") }

      let(:args) { { topic_id: topic.id, summary_type: "gist", locale: "en" } }

      it "replaces the gist in place" do
        DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) { job.execute(args) }

        expect(AiSummary.where(target: topic)).to contain_exactly(gist, other_locale_gist, summary)
        expect(gist.reload.summarized_text).to eq(replacement)
        expect(summary.reload.summarized_text).to eq("complete summary")
      end

      it "drops only that gist when generation fails" do
        DiscourseAi::Completions::Llm.with_prepared_responses([RuntimeError.new("LLM failed")]) do
          expect { job.execute(args) }.to raise_error(RuntimeError, "LLM failed")
        end

        expect(AiSummary.where(target: topic)).to contain_exactly(other_locale_gist, summary)
      end

      it "drops the gist when gists are disabled" do
        SiteSetting.ai_summary_gists_enabled = false

        job.execute(args)

        expect(AiSummary.where(target: topic)).to contain_exactly(other_locale_gist, summary)
      end

      it "drops the gist when the topic is gone" do
        topic.trash!

        job.execute(args)

        expect(AiSummary.gist.where(target_id: topic.id, locale: "en")).to be_empty
      end

      it "does nothing when the gist no longer exists" do
        AiSummary.where(id: gist.id).delete_all

        DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do |spy|
          job.execute(args)
          expect(spy.completions).to eq(0)
        end
      end
    end

    context "with a stale complete summary" do
      fab!(:summary) { Fabricate(:ai_summary, target: topic, locale: "en") }
      fab!(:gist) { Fabricate(:topic_ai_gist, target: topic, locale: "en") }

      let(:args) { { topic_id: topic.id, summary_type: "complete", locale: "en" } }

      it "replaces the summary in place" do
        DiscourseAi::Completions::Llm.with_prepared_responses([replacement]) { job.execute(args) }

        expect(AiSummary.where(target: topic)).to contain_exactly(summary, gist)
        expect(summary.reload.summarized_text).to eq(replacement)
      end

      it "drops the summary when generation fails" do
        DiscourseAi::Completions::Llm.with_prepared_responses([RuntimeError.new("LLM failed")]) do
          expect { job.execute(args) }.to raise_error(RuntimeError, "LLM failed")
        end

        expect(AiSummary.where(target: topic)).to contain_exactly(gist)
      end

      it "supersedes a summary stored without a locale" do
        summary.update_columns(locale: nil)

        DiscourseAi::Completions::Llm.with_prepared_responses([replacement]) do
          job.execute(args.merge(locale: nil))
        end

        expect(AiSummary.complete.where(target: topic).pluck(:summarized_text, :locale)).to eq(
          [[replacement, SiteSetting.default_locale]],
        )
      end
    end
  end
end
