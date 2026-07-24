# frozen_string_literal: true

RSpec.describe DiscourseTopicVoting::EnableTopicVotingBadgesToggled do
  let(:badge_names) { DiscourseTopicVoting::BADGE_NAMES }

  def topic_voting_badges
    Badge.where(name: badge_names)
  end

  describe "enabling" do
    before { topic_voting_badges.update_all(enabled: false) }

    it "enables all four Topic Voting badges" do
      described_class.call(enabled: true)

      expect(topic_voting_badges.where(enabled: true).count).to eq(4)
    end
  end

  describe "disabling" do
    before { topic_voting_badges.update_all(enabled: true) }

    it "disables all four Topic Voting badges" do
      described_class.call(enabled: false)

      expect(topic_voting_badges.where(enabled: false).count).to eq(4)
    end
  end
end
