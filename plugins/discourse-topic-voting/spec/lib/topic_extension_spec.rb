# frozen_string_literal: true

describe DiscourseTopicVoting::TopicExtension do
  let(:user) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }

  let(:topic) { Fabricate(:topic) }
  let(:topic2) { Fabricate(:topic) }

  before do
    SiteSetting.topic_voting_enabled = true
    SiteSetting.topic_voting_show_who_voted = true
  end

  describe "#update_vote_count" do
    it "upserts topic votes count" do
      topic.update_vote_count
      topic2.update_vote_count

      expect(topic.reload.topic_vote_count.votes_count).to eq(0)
      expect(topic2.reload.topic_vote_count.votes_count).to eq(0)

      DiscourseTopicVoting::Vote.create!(user: user, topic: topic)
      topic.update_vote_count
      topic2.update_vote_count

      expect(topic.reload.topic_vote_count.votes_count).to eq(1)
      expect(topic2.reload.topic_vote_count.votes_count).to eq(0)

      DiscourseTopicVoting::Vote.create!(user: user2, topic: topic)
      DiscourseTopicVoting::Vote.create!(user: user, topic: topic2)
      topic.update_vote_count
      topic2.update_vote_count

      expect(topic.reload.topic_vote_count.votes_count).to eq(2)
      expect(topic2.reload.topic_vote_count.votes_count).to eq(1)
    end
  end
end
