# frozen_string_literal: true

RSpec.describe DiscourseTopicVoting::Votes::Cast do
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

    context "when topic is hidden from the actor" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:topic) { Fabricate(:topic, category: private_category) }

      before do
        DiscourseTopicVoting::CategorySetting.create!(category: private_category)
        Category.reset_voting_cache
      end

      it { is_expected.to fail_a_policy(:can_see_topic) }
    end

    context "when topic is not votable" do
      before do
        category.discourse_topic_voting_category_setting.destroy!
        Category.reset_voting_cache
      end

      it { is_expected.to fail_a_policy(:topic_is_votable) }
    end

    context "when actor already voted" do
      before { DiscourseTopicVoting::Vote.create!(user: user, topic: topic) }

      it { is_expected.to fail_a_policy(:topic_not_already_voted) }
    end

    context "when actor reached vote limit" do
      before { SiteSetting.public_send("topic_voting_tl#{user.trust_level}_vote_limit=", 0) }

      it { is_expected.to fail_a_policy(:current_user_can_vote) }
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "creates a vote" do
        expect { result }.to change(DiscourseTopicVoting::Vote, :count).by(1)
      end

      it "updates the topic vote count" do
        result

        expect(topic.reload.vote_count).to eq(1)
      end

      it "enqueues the upvote webhook when configured" do
        Fabricate(:topic_voting_web_hook)

        expect { result }.to change(Jobs::EmitWebHookEvent.jobs, :size).by(1)

        job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
        expect(job_args["event_name"]).to eq("topic_upvote")

        payload = JSON.parse(job_args["payload"])
        expect(payload).to include(
          "topic_id" => topic.id,
          "topic_slug" => topic.slug,
          "voter_id" => user.id,
          "vote_count" => 1,
        )
      end

      it "does not enqueue the upvote webhook when not configured" do
        expect { result }.not_to change(Jobs::EmitWebHookEvent.jobs, :size)
      end

      it "enqueues the backfill badges job" do
        expect { result }.to change(Jobs::DiscourseTopicVoting::BackfillBadges.jobs, :size).by(1)
        expect(Jobs::DiscourseTopicVoting::BackfillBadges.jobs.last["args"].first).to include(
          "topic_id" => topic.id,
        )
      end
    end
  end
end
