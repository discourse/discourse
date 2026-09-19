# frozen_string_literal: true

RSpec.describe Jobs::DiscourseTopicVoting::BackfillBadges do
  fab!(:topic_author, :user)
  fab!(:topic) { Fabricate(:topic, user: topic_author) }
  fab!(:first_post) { Fabricate(:post, topic:, user: topic_author) }

  let(:daydreamer) { Badge.find_by(name: "Daydreamer") }
  let(:brainstormer) { Badge.find_by(name: "Brainstormer") }
  let(:innovator) { Badge.find_by(name: "Innovator") }
  let(:visionary) { Badge.find_by(name: "Visionary") }

  before { Badge.where(name: DiscourseTopicVoting::BADGE_NAMES).update_all(enabled: true) }

  describe "seeded badges" do
    it "seeds four badges with correct attributes" do
      expect(daydreamer.badge_type_id).to eq(BadgeType::Bronze)
      expect(brainstormer.badge_type_id).to eq(BadgeType::Silver)
      expect(innovator.badge_type_id).to eq(BadgeType::Silver)
      expect(visionary.badge_type_id).to eq(BadgeType::Gold)

      [daydreamer, brainstormer, innovator, visionary].each do |badge|
        expect(badge.icon).to eq("vote-up-filled")
        expect(badge.multiple_grant).to eq(true)
        expect(badge.target_posts).to eq(true)
        expect(badge.auto_revoke).to eq(true)
        expect(badge.system).to eq(true)
        expect(badge.query).to include("topic_voting_votes")
      end
    end
  end

  describe "#execute" do
    it "grants Daydreamer for a single vote" do
      Fabricate(:topic_voting_votes, topic:)

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: brainstormer).count).to eq(0)
      expect(UserBadge.find_by(user_id: topic_author.id, badge_id: daydreamer.id).post_id).to eq(
        first_post.id,
      )
    end

    it "grants Brainstormer at 5 votes" do
      5.times { Fabricate(:topic_voting_votes, topic:) }

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: brainstormer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: innovator).count).to eq(0)
    end

    it "grants Innovator at 15 votes" do
      15.times { Fabricate(:topic_voting_votes, topic:) }

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: brainstormer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: innovator).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: visionary).count).to eq(0)
    end

    it "grants Visionary at 25 votes" do
      25.times { Fabricate(:topic_voting_votes, topic:) }

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: brainstormer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: innovator).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: visionary).count).to eq(1)
    end

    it "does not count self-votes toward the threshold" do
      Fabricate(:topic_voting_votes, topic:, user: topic_author)

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(0)
    end

    it "ignores self-votes when tallying" do
      Fabricate(:topic_voting_votes, topic:, user: topic_author)
      4.times { Fabricate(:topic_voting_votes, topic:) }

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: brainstormer).count).to eq(0)
    end

    it "grants the badge separately for each qualifying topic (multi-grant)" do
      other_topic = Fabricate(:topic, user: topic_author)
      other_first_post = Fabricate(:post, topic: other_topic, user: topic_author)

      Fabricate(:topic_voting_votes, topic:)
      Fabricate(:topic_voting_votes, topic: other_topic)

      described_class.new.execute(topic_id: topic.id)
      described_class.new.execute(topic_id: other_topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(2)
      grant_post_ids =
        UserBadge.where(user_id: topic_author.id, badge_id: daydreamer.id).pluck(:post_id)
      expect(grant_post_ids).to contain_exactly(first_post.id, other_first_post.id)
    end

    it "is idempotent for the same topic" do
      5.times { Fabricate(:topic_voting_votes, topic:) }

      described_class.new.execute(topic_id: topic.id)
      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: brainstormer).count).to eq(1)
    end

    it "does not grant when the topic is deleted" do
      5.times { Fabricate(:topic_voting_votes, topic:) }
      topic.trash!

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(0)
      expect(UserBadge.where(user: topic_author, badge: brainstormer).count).to eq(0)
    end

    it "does not grant for non-regular archetypes" do
      topic.update_columns(archetype: Archetype.private_message, category_id: nil)
      5.times { Fabricate(:topic_voting_votes, topic:) }

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(0)
    end

    it "does nothing when badges are disabled site-wide" do
      SiteSetting.enable_badges = false
      5.times { Fabricate(:topic_voting_votes, topic:) }

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(0)
    end

    it "does nothing when a badge is disabled" do
      daydreamer.update!(enabled: false)
      Fabricate(:topic_voting_votes, topic:)

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(0)
    end

    it "does not grant for unlisted topics" do
      topic.update!(visible: false)
      Fabricate(:topic_voting_votes, topic:)

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(0)
    end

    it "does not grant when the category does not allow badges" do
      topic.category.update!(allow_badges: false)
      Fabricate(:topic_voting_votes, topic:)

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(0)
    end

    it "suppresses the granted-badge notification when the qualifying votes are older than 2 weeks" do
      5.times { Fabricate(:topic_voting_votes, topic:) }
      DiscourseTopicVoting::Vote.update_all(created_at: 3.weeks.ago)

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.where(user: topic_author, badge: daydreamer).count).to eq(1)
      expect(UserBadge.where(user: topic_author, badge: brainstormer).count).to eq(1)
      expect(
        UserBadge.where(user: topic_author, badge: [daydreamer, brainstormer]).pluck(
          :notification_id,
        ),
      ).to all(be_nil)
    end

    it "still notifies when the qualifying votes are recent" do
      5.times { Fabricate(:topic_voting_votes, topic:) }

      described_class.new.execute(topic_id: topic.id)

      expect(
        UserBadge.find_by(user: topic_author, badge: brainstormer).notification_id,
      ).to be_present
    end

    it "only notifies for the highest tier reached when older tiers were crossed long ago" do
      4.times { Fabricate(:topic_voting_votes, topic:) }
      DiscourseTopicVoting::Vote.update_all(created_at: 3.weeks.ago)
      Fabricate(:topic_voting_votes, topic:)

      described_class.new.execute(topic_id: topic.id)

      expect(UserBadge.find_by(user: topic_author, badge: daydreamer).notification_id).to be_nil
      expect(
        UserBadge.find_by(user: topic_author, badge: brainstormer).notification_id,
      ).to be_present
    end
  end
end
