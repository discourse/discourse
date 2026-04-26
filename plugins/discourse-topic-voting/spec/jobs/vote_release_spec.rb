# frozen_string_literal: true

RSpec.describe Jobs::DiscourseTopicVoting::VoteRelease do
  context "when the topic does not exist" do
    fab!(:topic)

    it "does nothing" do
      topic.destroy!
      Topic.any_instance.expects(:update_vote_count).never
      Jobs::DiscourseTopicVoting::VoteRelease.new.execute(topic_id: topic.id)
    end
  end

  context "when the topic exists" do
    fab!(:topic)

    it "releases the votes" do
      vote = Fabricate(:topic_voting_votes, topic: topic, archive: false)
      expect { Jobs::DiscourseTopicVoting::VoteRelease.new.execute(topic_id: topic.id) }.to change {
        vote.reload.archived
      }.from(false).to(true)
    end

    it "creates a notification for the user about the votes being released" do
      vote = Fabricate(:topic_voting_votes, topic: topic, archive: false)
      expect { Jobs::DiscourseTopicVoting::VoteRelease.new.execute(topic_id: topic.id) }.to change {
        Notification.where(
          user_id: vote.user_id,
          notification_type: Notification.types[:votes_released],
        ).count
      }.by(1)
    end

    context "when the topic is trashed" do
      before { topic.trash! }

      it "does not create a notification for the user" do
        vote = Fabricate(:topic_voting_votes, topic: topic, archive: false)
        expect {
          Jobs::DiscourseTopicVoting::VoteRelease.new.execute(topic_id: topic.id, trashed: true)
        }.not_to change {
          Notification.where(
            user_id: vote.user_id,
            notification_type: Notification.types[:votes_released],
          ).count
        }
      end
    end
  end
end
