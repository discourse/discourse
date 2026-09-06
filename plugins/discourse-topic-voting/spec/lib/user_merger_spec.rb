# frozen_string_literal: true

describe DiscourseTopicVoting::UserMerger do
  fab!(:source_user, :user)
  fab!(:target_user, :user)
  fab!(:topic1, :topic)
  fab!(:topic2, :topic)
  fab!(:topic3, :topic)
  fab!(:topic4, :topic)

  subject(:user_merger) { UserMerger.new(source_user, target_user) }

  before { SiteSetting.topic_voting_enabled = true }

  context "when merging users with votes" do
    it "transfers source user votes to target user" do
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic2)

      expect(source_user.vote_count).to eq(2)
      expect(target_user.vote_count).to eq(0)

      user_merger.merge!

      target_user.reload
      expect(target_user.vote_count).to eq(2)
      expect(target_user.topics_with_vote.pluck(:topic_id)).to contain_exactly(topic1.id, topic2.id)

      expect(DiscourseTopicVoting::Vote.where(user_id: source_user.id).count).to eq(0)
    end

    it "handles duplicate votes by keeping target's vote and removing source's vote" do
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: target_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic2)

      user_merger.merge!

      target_user.reload
      expect(target_user.vote_count).to eq(2)
      expect(target_user.topics_with_vote.pluck(:topic_id)).to contain_exactly(topic1.id, topic2.id)

      votes = DiscourseTopicVoting::Vote.where(topic_id: topic1.id, user_id: target_user.id)
      expect(votes.count).to eq(1)
      expect(DiscourseTopicVoting::Vote.where(user_id: source_user.id).count).to eq(0)
    end

    it "handles mixed scenarios with some duplicates and some unique votes" do
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic2)
      DiscourseTopicVoting::Vote.create!(user: target_user, topic: topic2)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic3)

      user_merger.merge!

      target_user.reload
      expect(target_user.vote_count).to eq(3)
      expect(target_user.topics_with_vote.pluck(:topic_id)).to contain_exactly(
        topic1.id,
        topic2.id,
        topic3.id,
      )

      expect(
        DiscourseTopicVoting::Vote.where(topic_id: topic2.id, user_id: target_user.id).count,
      ).to eq(1)
    end

    it "transfers archived votes correctly" do
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1, archive: true)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic2, archive: false)

      user_merger.merge!

      target_user.reload
      expect(target_user.topics_with_vote.pluck(:topic_id)).to contain_exactly(topic2.id)
      expect(target_user.topics_with_archived_vote.pluck(:topic_id)).to contain_exactly(topic1.id)
    end

    it "updates topic vote counts accurately after merge" do
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic2)
      DiscourseTopicVoting::Vote.create!(user: target_user, topic: topic2)

      topic1.update_vote_count
      topic2.update_vote_count

      expect(topic1.topic_vote_count.votes_count).to eq(1)
      expect(topic2.topic_vote_count.votes_count).to eq(2)

      user_merger.merge!

      topic1.reload
      topic2.reload

      expect(topic1.topic_vote_count.votes_count).to eq(1)
      expect(topic2.topic_vote_count.votes_count).to eq(1)
    end

    it "prevents target user from casting new votes when over limit after merge" do
      SiteSetting.topic_voting_tl0_vote_limit = 2
      source_user.update!(trust_level: 0)
      target_user.update!(trust_level: 0)

      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic2)
      DiscourseTopicVoting::Vote.create!(user: target_user, topic: topic3)

      expect(source_user.reached_voting_limit?).to eq(true)
      expect(target_user.reached_voting_limit?).to eq(false)

      user_merger.merge!

      target_user.reload
      expect(target_user.vote_count).to eq(3)
      expect(target_user.reached_voting_limit?).to eq(true)
    end

    it "handles merge when source user has no votes" do
      DiscourseTopicVoting::Vote.create!(user: target_user, topic: topic1)

      expect { user_merger.merge! }.not_to raise_error

      target_user.reload
      expect(target_user.vote_count).to eq(1)
    end

    it "handles merge when both users have no votes" do
      expect { user_merger.merge! }.not_to raise_error

      target_user.reload
      expect(target_user.vote_count).to eq(0)
    end

    it "handles merge when all source votes are duplicates" do
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic2)
      DiscourseTopicVoting::Vote.create!(user: target_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: target_user, topic: topic2)

      user_merger.merge!

      target_user.reload
      expect(target_user.vote_count).to eq(2)
      expect(DiscourseTopicVoting::Vote.where(user_id: source_user.id).count).to eq(0)
    end

    it "preserves vote timestamps correctly" do
      created_at = 2.days.ago
      vote = DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1)
      vote.update_column(:created_at, created_at)

      user_merger.merge!

      merged_vote = DiscourseTopicVoting::Vote.find_by(user_id: target_user.id, topic_id: topic1.id)
      expect(merged_vote.created_at.to_i).to eq(created_at.to_i)
    end

    it "handles archived duplicate votes correctly" do
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1, archive: true)
      DiscourseTopicVoting::Vote.create!(user: target_user, topic: topic1, archive: false)

      user_merger.merge!

      target_user.reload
      expect(target_user.topics_with_vote.pluck(:topic_id)).to contain_exactly(topic1.id)
      expect(target_user.topics_with_archived_vote.pluck(:topic_id)).to be_empty
      expect(
        DiscourseTopicVoting::Vote.where(topic_id: topic1.id, user_id: target_user.id).count,
      ).to eq(1)
    end

    it "maintains vote count integrity across multiple topics" do
      other_user = Fabricate(:user)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: target_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: other_user, topic: topic1)
      DiscourseTopicVoting::Vote.create!(user: source_user, topic: topic2)

      topic1.update_vote_count
      topic2.update_vote_count

      expect(topic1.topic_vote_count.votes_count).to eq(3)
      expect(topic2.topic_vote_count.votes_count).to eq(1)

      user_merger.merge!

      topic1.reload
      topic2.reload

      expect(topic1.topic_vote_count.votes_count).to eq(2)
      expect(topic2.topic_vote_count.votes_count).to eq(1)
    end
  end
end
