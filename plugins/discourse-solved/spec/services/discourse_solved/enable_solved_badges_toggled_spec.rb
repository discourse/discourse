# frozen_string_literal: true

RSpec.describe DiscourseSolved::EnableSolvedBadgesToggled do
  let(:badge_names) { DiscourseSolved::EnableSolvedBadgesToggled::BADGE_NAMES }

  def solved_badges
    Badge.where(name: badge_names)
  end

  describe "enabling" do
    before { solved_badges.update_all(enabled: false) }

    it "enables all four Solved badges" do
      described_class.call(enabled: true)

      expect(solved_badges.where(enabled: true).count).to eq(4)
    end
  end

  describe "disabling" do
    before { solved_badges.update_all(enabled: true) }

    it "disables all four Solved badges" do
      described_class.call(enabled: false)

      expect(solved_badges.where(enabled: false).count).to eq(4)
    end
  end
end
