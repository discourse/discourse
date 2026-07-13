# frozen_string_literal: true

RSpec.describe "Enable Topic Voting badges by default upcoming change" do
  let(:badge_names) { DiscourseTopicVoting::BADGE_NAMES }

  def reseed_topic_voting_badges
    Badge.where(name: badge_names).delete_all
    load Rails.root.join("plugins/discourse-topic-voting/db/fixtures/001_badges.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative
  end

  describe "seeding the Topic Voting badges on a new site" do
    it "enables the badges by default" do
      reseed_topic_voting_badges

      expect(Badge.where(name: badge_names).pluck(:enabled)).to all(eq(true))
    end
  end

  describe "conditional display" do
    it "is displayed only on sites where the Topic Voting plugin is enabled" do
      SiteSetting.topic_voting_enabled = true
      expect(UpcomingChanges::ConditionalDisplay.should_display_enable_topic_voting_badges?).to eq(
        true,
      )

      SiteSetting.topic_voting_enabled = false
      expect(UpcomingChanges::ConditionalDisplay.should_display_enable_topic_voting_badges?).to eq(
        false,
      )
    end
  end
end
