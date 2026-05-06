# frozen_string_literal: true

RSpec.describe Jobs::DiscourseTopicVoting::VoteReclaim do
  context "when the topic does not exist" do
    fab!(:topic)

    it "does nothing" do
      topic.destroy!
      Topic.any_instance.expects(:update_vote_count).never
      Jobs::DiscourseTopicVoting::VoteReclaim.new.execute(topic_id: topic.id)
    end
  end

  context "when the topic exists" do
    fab!(:topic)

    it "updates the vote count" do
      Fabricate(:topic_voting_votes, topic: topic, archive: true)
      expect { Jobs::DiscourseTopicVoting::VoteReclaim.new.execute(topic_id: topic.id) }.to change {
        topic.reload.vote_count
      }.by(1)
    end

    it "reclaims the votes" do
      vote = Fabricate(:topic_voting_votes, topic: topic, archive: true)
      expect { Jobs::DiscourseTopicVoting::VoteReclaim.new.execute(topic_id: topic.id) }.to change {
        vote.reload.archived
      }.from(true).to(false)
    end

    it "enqueues the backfill badges job" do
      Fabricate(:topic_voting_votes, topic:, archive: true)
      expect { Jobs::DiscourseTopicVoting::VoteReclaim.new.execute(topic_id: topic.id) }.to change(
        Jobs::DiscourseTopicVoting::BackfillBadges.jobs,
        :size,
      ).by(1)
    end

    context "when the topic is deleted" do
      before { topic.trash! }

      it "reclaims the votes" do
        vote = Fabricate(:topic_voting_votes, topic: topic, archive: true)
        expect {
          Jobs::DiscourseTopicVoting::VoteReclaim.new.execute(topic_id: topic.id)
        }.to change { vote.reload.archived }.from(true).to(false)
      end
    end
  end
end
