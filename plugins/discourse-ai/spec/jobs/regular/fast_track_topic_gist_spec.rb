# frozen_string_literal: true

RSpec.describe Jobs::FastTrackTopicGist do
  subject(:job) { described_class.new }

  fab!(:topic, :topic)
  fab!(:post_1) { Fabricate(:post, topic:, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic:, post_number: 2) }

  let(:updated_gist) { "They updated me :(" }
  let(:tool_call) do
    DiscourseAi::Completions::ToolCall.new(
      id: "call_1",
      name: "set_topic_summary",
      parameters: {
        summary: updated_gist,
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
    context "when the topic has a gist" do
      fab!(:ai_gist) do
        Fabricate(
          :topic_ai_gist,
          target: topic,
          locale: "en",
          original_content_sha: AiSummary.build_sha("12"),
          created_at: 10.minutes.ago,
        )
      end

      it "keeps an up-to-date gist" do
        DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do |spy|
          job.execute(topic_id: topic.id, locale: "en")
          expect(spy.completions).to eq(0)
        end

        expect(ai_gist.reload.summarized_text).not_to eq(updated_gist)
      end

      it "regenerates an up-to-date gist when forced" do
        DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do
          job.execute(topic_id: topic.id, locale: "en", force_regenerate: true)
        end

        expect(ai_gist.reload.summarized_text).to eq(updated_gist)
      end

      it "preserves the gist when forced generation fails" do
        DiscourseAi::Completions::Llm.with_prepared_responses([RuntimeError.new("LLM failed")]) do
          expect do
            job.execute(topic_id: topic.id, locale: "en", force_regenerate: true)
          end.to raise_error(RuntimeError, "LLM failed")
        end

        expect(ai_gist.reload.summarized_text).to eq("gist")
      end

      it "regenerates an outdated gist using the latest data" do
        Fabricate(:post, topic:, post_number: 3)

        DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do
          job.execute(topic_id: topic.id, locale: "en")
        end

        expect(ai_gist.reload).to have_attributes(
          summarized_text: updated_gist,
          original_content_sha: AiSummary.build_sha("123"),
        )
      end

      it "throttles recently-created outdated gists" do
        Fabricate(:post, topic:, post_number: 3)
        ai_gist.update!(created_at: 2.minutes.ago)

        DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do |spy|
          job.execute(topic_id: topic.id, locale: "en")
          expect(spy.completions).to eq(0)
        end

        expect(ai_gist.reload.original_content_sha).to eq(AiSummary.build_sha("12"))
      end

      it "regenerates a recently-created outdated gist when forced" do
        Fabricate(:post, topic:, post_number: 3)
        ai_gist.update!(created_at: 2.minutes.ago)

        DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do
          job.execute(topic_id: topic.id, locale: "en", force_regenerate: true)
        end

        expect(ai_gist.reload).to have_attributes(
          summarized_text: updated_gist,
          original_content_sha: AiSummary.build_sha("123"),
        )
      end

      it "stores another locale without replacing the existing gist" do
        japanese_tool_call =
          DiscourseAi::Completions::ToolCall.new(
            id: "call_ja",
            name: "set_topic_summary",
            parameters: {
              summary: "日本語の要約",
            },
          )

        DiscourseAi::Completions::Llm.with_prepared_responses([japanese_tool_call]) do
          job.execute(topic_id: topic.id, locale: "ja")
        end

        expect(
          AiSummary.gist.where(target: topic).pluck(:locale, :summarized_text),
        ).to contain_exactly(["en", ai_gist.summarized_text], %w[ja 日本語の要約])
      end
    end

    it "does nothing when no gist agent is available" do
      SiteSetting.ai_summary_gists_agent = 999_999
      AiAgent.agent_cache.flush!

      expect { job.execute(topic_id: topic.id, locale: "en") }.not_to raise_error
      expect(AiSummary.gist.where(target: topic)).to be_empty
    end

    it "uses the source locale for a legacy job without a locale" do
      topic.update!(locale: "ja")
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "en|ja"

      DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do
        job.execute(topic_id: topic.id)
      end

      expect(AiSummary.gist.find_by(target: topic)).to have_attributes(locale: "ja")
    end

    it "reuses an equivalent regional-locale gist" do
      topic.update!(locale: "pt_BR")
      existing_gist =
        Fabricate(
          :topic_ai_gist,
          target: topic,
          locale: "pt",
          original_content_sha: AiSummary.build_sha("12"),
        )

      DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do |spy|
        job.execute(topic_id: topic.id, locale: "pt_BR")
        expect(spy.completions).to eq(0)
      end

      expect(existing_gist.reload.summarized_text).not_to eq(updated_gist)
    end

    it "creates a gist without a hot topic score" do
      DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do
        job.execute(topic_id: topic.id, locale: "en")
      end

      expect(AiSummary.gist.find_by(target: topic, locale: "en")).to be_present
    end

    it "creates a gist for a hot topic" do
      TopicHotScore.create!(topic_id: topic.id, score: 0.1)

      DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do
        job.execute(topic_id: topic.id, locale: "en")
      end

      expect(AiSummary.gist.find_by(target: topic, locale: "en")).to be_present
    end
  end
end
