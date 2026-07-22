# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::RegenerateSummaries do
  describe ".call" do
    subject(:result) { described_class.call(**params, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:group)
    fab!(:topic)
    fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:topic_1, :topic)
    fab!(:post_2) { Fabricate(:post, topic: topic_1, post_number: 1) }

    let(:params) { { params: { topic_id: topic.id, type: type } } }
    let(:dependencies) { { guardian: admin.guardian } }

    before do
      enable_current_plugin
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_summarization_enabled = true

      group.add(admin)
    end

    shared_examples "common validation" do
      context "when topic_id is missing" do
        let(:params) { { params: { type: type } } }

        it { is_expected.to fail_a_contract }
      end

      context "when too many topics are provided" do
        let(:params) do
          { params: { topic_ids: 31.times.map { Fabricate(:topic).id }, type: type } }
        end

        it { is_expected.to fail_a_contract }
      end

      context "when user cannot see the topic" do
        fab!(:moderator)
        let(:private_topic) do
          private_group = Fabricate(:group)
          private_category = Fabricate(:private_category, group: private_group)
          Fabricate(:topic, category: private_category)
        end
        let(:params) { { params: { topic_id: private_topic.id, type: type } } }
        let(:dependencies) { { guardian: moderator.guardian } }

        before { group.add(moderator) }

        it "raises InvalidAccess" do
          expect { result }.to raise_error(Discourse::InvalidAccess)
        end
      end
    end

    context "when type is gist" do
      let(:type) { "gist" }

      before do
        SiteSetting.ai_summary_gists_enabled = true
        assign_agent_to(:ai_summary_gists_agent, [group.id])
      end

      include_examples "common validation"

      context "when user cannot request gists" do
        let(:dependencies) { { guardian: user.guardian } }

        it { is_expected.to fail_a_policy(:can_regenerate) }
      end

      context "when regenerating a single topic" do
        it { is_expected.to run_successfully }

        it "enqueues a forced gist generation job for the default locale" do
          expect { result }.to change { Jobs::FastTrackTopicGist.jobs.size }.by(1)

          job_args = Jobs::FastTrackTopicGist.jobs.first["args"].first
          expect(job_args).to include(
            "topic_id" => topic.id,
            "locale" => SiteSetting.default_locale,
            "force_regenerate" => true,
          )
        end

        it "preserves cached gists while enqueueing forced replacements" do
          english_gist = Fabricate(:topic_ai_gist, target: topic, locale: "en")
          hebrew_gist = Fabricate(:topic_ai_gist, target: topic, locale: "he")

          result

          expect(AiSummary.where(id: [english_gist.id, hebrew_gist.id])).to contain_exactly(
            english_gist,
            hebrew_gist,
          )
          expect(Jobs::FastTrackTopicGist.jobs.first.dig("args", 0)).to include(
            "force_regenerate" => true,
          )
        end
      end

      context "when regenerating multiple topics" do
        let(:params) { { params: { topic_ids: [topic.id, topic_1.id], type: type } } }

        it { is_expected.to run_successfully }

        it "enqueues jobs for all topics" do
          expect { result }.to change { Jobs::FastTrackTopicGist.jobs.size }.by(2)
        end
      end
    end

    context "when type is summary" do
      let(:type) { "summary" }

      before { assign_agent_to(:ai_summarization_agent, [group.id]) }

      include_examples "common validation"

      context "when user cannot regenerate summaries" do
        let(:dependencies) { { guardian: user.guardian } }

        it { is_expected.to fail_a_policy(:can_regenerate) }
      end

      context "when regenerating a single topic" do
        it { is_expected.to run_successfully }

        it "enqueues the summary generation job" do
          expect { result }.to change { Jobs::StreamTopicAiSummary.jobs.size }.by(1)
        end

        it "enqueues a forced job instead of using the age-check override" do
          result

          job_args = Jobs::StreamTopicAiSummary.jobs.first["args"].first
          expect(job_args).to include(
            "topic_id" => topic.id,
            "user_id" => admin.id,
            "locale" => SiteSetting.default_locale,
            "force_regenerate" => true,
          )
          expect(job_args).not_to have_key("skip_age_check")
        end

        it "preserves cached summary locales while enqueueing a replacement" do
          SiteSetting.content_localization_enabled = true
          SiteSetting.content_localization_supported_locales = "he"
          topic.update!(locale: "en")
          english_summary = Fabricate(:ai_summary, target: topic, locale: "en")
          hebrew_summary = Fabricate(:ai_summary, target: topic, locale: "he")

          I18n.with_locale(:he) { result }

          expect(AiSummary.where(id: [english_summary.id, hebrew_summary.id])).to contain_exactly(
            english_summary,
            hebrew_summary,
          )
          expect(Jobs::StreamTopicAiSummary.jobs.first.dig("args", 0, "locale")).to eq("he")
        end
      end

      context "when regenerating multiple topics" do
        let(:params) { { params: { topic_ids: [topic.id, topic_1.id], type: type } } }

        it { is_expected.to run_successfully }

        it "enqueues jobs for all topics" do
          expect { result }.to change { Jobs::StreamTopicAiSummary.jobs.size }.by(2)
        end
      end
    end

    context "when type is invalid" do
      let(:type) { "invalid" }

      it { is_expected.to fail_a_contract }
    end
  end
end
