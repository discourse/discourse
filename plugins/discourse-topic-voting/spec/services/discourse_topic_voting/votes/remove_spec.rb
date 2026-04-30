# frozen_string_literal: true

RSpec.describe DiscourseTopicVoting::Votes::Remove do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }

    let(:params) { { topic_id: topic_id } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:topic_id) { topic.id }

    before do
      SiteSetting.topic_voting_enabled = true
      DiscourseTopicVoting::CategorySetting.create!(category: category)
      Category.reset_voting_cache
    end

    context "when params are invalid" do
      let(:topic_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when topic is missing" do
      let(:topic_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when topic is hidden" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:topic) { Fabricate(:topic, category: private_category) }

      before do
        DiscourseTopicVoting::CategorySetting.create!(category: private_category)
        Category.reset_voting_cache
      end

      it { is_expected.to fail_a_policy(:can_see_topic) }
    end

    context "when no active vote exists" do
      before { topic.update_vote_count }

      it { is_expected.to run_successfully }

      it "does not change vote rows" do
        expect { result }.not_to change(DiscourseTopicVoting::Vote, :count)
      end

      it "does not change the topic vote count" do
        expect { result }.not_to change { topic.reload.vote_count }
      end
    end

    context "when only an archived vote exists" do
      fab!(:archived_vote) { Fabricate(:topic_voting_votes, user: user, topic: topic) }

      before do
        archived_vote.update!(archive: true)
        topic.update_vote_count
      end

      it { is_expected.to run_successfully }

      it "keeps the archived vote" do
        expect { result }.not_to change(DiscourseTopicVoting::Vote, :count)
        expect(archived_vote.reload.archive).to eq(true)
      end

      it "does not change the topic vote count" do
        expect { result }.not_to change { topic.reload.vote_count }
      end
    end

    context "when an active vote exists" do
      fab!(:active_vote) { Fabricate(:topic_voting_votes, user: user, topic: topic) }

      before { topic.update_vote_count }

      it { is_expected.to run_successfully }

      it "removes only the active vote" do
        expect { result }.to change(DiscourseTopicVoting::Vote, :count).by(-1)
        expect { active_vote.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "updates the topic vote count" do
        result

        expect(topic.reload.vote_count).to eq(0)
      end

      it "enqueues the unvote webhook when configured" do
        Fabricate(:topic_voting_web_hook)

        expect { result }.to change(Jobs::EmitWebHookEvent.jobs, :size).by(1)

        job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
        expect(job_args["event_name"]).to eq("topic_unvote")

        payload = JSON.parse(job_args["payload"])
        expect(payload).to include(
          "topic_id" => topic.id,
          "topic_slug" => topic.slug,
          "voter_id" => user.id,
          "vote_count" => 0,
        )
      end

      it "does not enqueue the unvote webhook when not configured" do
        expect { result }.not_to change(Jobs::EmitWebHookEvent.jobs, :size)
      end

      it "does not enqueue the backfill badges job" do
        expect { result }.not_to change(Jobs::DiscourseTopicVoting::BackfillBadges.jobs, :size)
      end
    end
  end
end
