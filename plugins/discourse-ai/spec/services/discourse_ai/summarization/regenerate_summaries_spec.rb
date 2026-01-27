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

    let(:params) { { params: { topic_id: topic.id } } }
    let(:dependencies) { { guardian: admin.guardian } }

    before do
      enable_current_plugin
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_summarization_enabled = true

      group.add(admin)
      assign_persona_to(:ai_summarization_persona, [group.id])
    end

    context "when topic_id is missing" do
      let(:params) { { params: {} } }

      it { is_expected.to fail_a_contract }
    end

    context "when too many topics are provided" do
      let(:params) { { params: { topic_ids: 31.times.map { Fabricate(:topic).id } } } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot regenerate summaries" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_regenerate_summary) }
    end

    context "when user cannot see the topic" do
      fab!(:moderator)
      let(:private_topic) do
        private_group = Fabricate(:group)
        private_category = Fabricate(:private_category, group: private_group)
        Fabricate(:topic, category: private_category)
      end
      let(:params) { { params: { topic_id: private_topic.id } } }
      let(:dependencies) { { guardian: moderator.guardian } }

      before { group.add(moderator) }

      it "raises InvalidAccess" do
        expect { result }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when regenerating a single topic" do
      it { is_expected.to run_successfully }

      it "enqueues the summary generation job" do
        expect { result }.to change { Jobs::StreamTopicAiSummary.jobs.size }.by(1)
      end

      it "enqueues job with correct parameters" do
        result

        job_args = Jobs::StreamTopicAiSummary.jobs.first["args"].first
        expect(job_args["topic_id"]).to eq(topic.id)
        expect(job_args["user_id"]).to eq(admin.id)
        expect(job_args["skip_age_check"]).to eq(true)
      end

      it "deletes existing cached summary" do
        summary = Fabricate(:ai_summary, target: topic)

        result

        expect(AiSummary.find_by(id: summary.id)).to be_nil
      end
    end

    context "when regenerating multiple topics" do
      let(:params) { { params: { topic_ids: [topic.id, topic_1.id] } } }

      it { is_expected.to run_successfully }

      it "enqueues jobs for all topics" do
        expect { result }.to change { Jobs::StreamTopicAiSummary.jobs.size }.by(2)
      end
    end
  end
end
