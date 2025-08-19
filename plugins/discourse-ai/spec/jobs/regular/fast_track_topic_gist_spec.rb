# frozen_string_literal: true

RSpec.describe Jobs::FastTrackTopicGist do
  subject(:job) { described_class.new }

  describe "#execute" do
    fab!(:topic_1) { Fabricate(:topic) }
    fab!(:post_1) { Fabricate(:post, topic: topic_1, post_number: 1) }
    fab!(:post_2) { Fabricate(:post, topic: topic_1, post_number: 2) }

    before do
      enable_current_plugin
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_summarization_enabled = true
      SiteSetting.ai_summary_gists_enabled = true
    end

    context "when the topic has a gist" do
      fab!(:ai_gist) do
        Fabricate(
          :topic_ai_gist,
          target: topic_1,
          original_content_sha: AiSummary.build_sha("12"),
          created_at: 10.minutes.ago,
        )
      end

      let(:updated_gist) { "They updated me :(" }

      context "when it's up to date" do
        it "does nothing" do
          DiscourseAi::Completions::Llm.with_prepared_responses([updated_gist]) do
            job.execute(topic_id: topic_1.id)
          end

          gist = AiSummary.gist.find_by(target: topic_1)
          expect(AiSummary.gist.where(target: topic_1).count).to eq(1)
          expect(gist.summarized_text).not_to eq(updated_gist)
        end

        it "regenerates when force_regenerate is true" do
          DiscourseAi::Completions::Llm.with_prepared_responses([updated_gist]) do
            job.execute(topic_id: topic_1.id, force_regenerate: true)
          end

          gist = AiSummary.gist.find_by(target: topic_1)
          expect(AiSummary.gist.where(target: topic_1).count).to eq(1)
          expect(gist.summarized_text).to eq(updated_gist)
        end
      end

      context "when it's outdated" do
        before { Fabricate(:post, topic: topic_1, post_number: 3) }

        it "regenerates the gist using the latest data" do
          DiscourseAi::Completions::Llm.with_prepared_responses([updated_gist]) do
            job.execute(topic_id: topic_1.id)
          end

          gist = AiSummary.gist.find_by(target: topic_1)
          expect(AiSummary.gist.where(target: topic_1).count).to eq(1)
          expect(gist.summarized_text).to eq(updated_gist)
          expect(gist.original_content_sha).to eq(AiSummary.build_sha("123"))
        end

        it "does nothing if the gist was created less than 5 minutes ago" do
          ai_gist.update!(created_at: 2.minutes.ago)

          DiscourseAi::Completions::Llm.with_prepared_responses([updated_gist]) do
            job.execute(topic_id: topic_1.id)
          end

          gist = AiSummary.gist.find_by(target: topic_1)
          expect(AiSummary.gist.where(target: topic_1).count).to eq(1)
          expect(gist.summarized_text).not_to eq(updated_gist)
          expect(gist.original_content_sha).to eq(AiSummary.build_sha("12"))
        end

        it "regenerates when force_regenerate is true even if created recently" do
          ai_gist.update!(created_at: 2.minutes.ago)

          DiscourseAi::Completions::Llm.with_prepared_responses([updated_gist]) do
            job.execute(topic_id: topic_1.id, force_regenerate: true)
          end

          gist = AiSummary.gist.find_by(target: topic_1)
          expect(AiSummary.gist.where(target: topic_1).count).to eq(1)
          expect(gist.summarized_text).to eq(updated_gist)
          expect(gist.original_content_sha).to eq(AiSummary.build_sha("123"))
        end
      end
    end

    context "when the topic doesn't have a hot topic score" do
      it "creates gist" do
        job.execute(topic_id: topic_1.id)

        gist = AiSummary.gist.find_by(target: topic_1)
        expect(gist).to be_present
      end
    end

    context "when the topic has a hot topic score but no gist" do
      before { TopicHotScore.create!(topic_id: topic_1.id, score: 0.1) }

      it "creates gist" do
        job.execute(topic_id: topic_1.id)

        gist = AiSummary.gist.find_by(target: topic_1)
        expect(gist).to be_present
      end
    end
  end
end
