# frozen_string_literal: true

RSpec.describe "Solved badge seeds" do
  let(:badge_names) { ["Solved 1", "Solved 2", "Solved 3", "Solved 4"] }

  describe "seeding the Solved badges on a new site" do
    it "enables the badges by default" do
      Badge.where(name: badge_names).delete_all
      load Rails.root.join("plugins/discourse-solved/db/fixtures/001_badges.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative

      expect(Badge.where(name: badge_names).pluck(:enabled)).to all(eq(true))
    end
  end
end
