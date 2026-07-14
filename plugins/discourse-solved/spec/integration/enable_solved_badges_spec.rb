# frozen_string_literal: true

RSpec.describe "Enable Solved badges by default upcoming change" do
  let(:badge_names) { ["Solved 1", "Solved 2", "Solved 3", "Solved 4"] }

  def reseed_solved_badges
    Badge.where(name: badge_names).delete_all
    load Rails.root.join("plugins/discourse-solved/db/fixtures/001_badges.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative
  end

  describe "seeding the Solved badges on a new site" do
    it "enables the badges by default" do
      reseed_solved_badges

      expect(Badge.where(name: badge_names).pluck(:enabled)).to all(eq(true))
    end
  end

  describe "conditional display" do
    it "is displayed on sites where the Solved plugin is enabled" do
      SiteSetting.solved_enabled = true

      expect(UpcomingChanges::ConditionalDisplay.should_display?(:enable_solved_badges)).to eq(true)
    end
  end
end
