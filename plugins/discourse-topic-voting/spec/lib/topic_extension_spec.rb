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

  describe "#who_voted" do
    it "returns recent active voters up to the requested limit" do
      DiscourseTopicVoting::Vote.create!(user: user, topic: topic, created_at: 2.hours.ago)
      DiscourseTopicVoting::Vote.create!(user: user2, topic: topic, created_at: 1.hour.ago)
      archived_user = Fabricate(:user)
      DiscourseTopicVoting::Vote.create!(
        user: archived_user,
        topic: topic,
        archive: true,
        created_at: Time.zone.now,
      )

      expect(topic.who_voted(limit: 1)).to eq([user2])
    end
  end

  describe "topic associations" do
    it "keeps soft-deleted topics available from votes and vote counts" do
      vote = DiscourseTopicVoting::Vote.create!(user: user, topic: topic)
      topic_vote_count = DiscourseTopicVoting::TopicVoteCount.create!(topic: topic, votes_count: 1)

      topic.trash!

      expect(vote.reload.topic).to eq(topic)
      expect(topic_vote_count.reload.topic).to eq(topic)
    end
  end
end
