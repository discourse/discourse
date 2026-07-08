# frozen_string_literal: true

RSpec.describe DiscourseSolved::EnableSolvedBadgesToggled do
  let(:badge_names) { DiscourseSolved::EnableSolvedBadgesToggled::BADGE_NAMES }

  def solved_badges
    Badge.where(name: badge_names)
  end

  before { solved_badges.update_all(enabled: false) }

  describe "enabling" do
    it "enables all four Solved badges" do
      described_class.call(enabled: true)

      expect(solved_badges.where(enabled: true).count).to eq(4)
    end

    it "snapshots the prior enabled state onto the existing opt-in event" do
      Badge.where(name: "Solved 1").update_all(enabled: true)
      event =
        UpcomingChangeEvent.create!(
          event_type: :manual_opt_in,
          upcoming_change_name: "enable_solved_badges",
        )

      described_class.call(enabled: true)

      expect(event.reload.event_data).to eq(
        "Solved 1" => true,
        "Solved 2" => false,
        "Solved 3" => false,
        "Solved 4" => false,
      )
    end

    it "captures the snapshot only once" do
      event =
        UpcomingChangeEvent.create!(
          event_type: :automatically_promoted,
          upcoming_change_name: "enable_solved_badges",
          event_data: {
            "Solved 1" => true,
          },
        )

      described_class.call(enabled: true)

      expect(event.reload.event_data).to eq("Solved 1" => true)
    end
  end

  describe "disabling" do
    it "restores each badge to its snapshotted state" do
      UpcomingChangeEvent.create!(
        event_type: :manual_opt_in,
        upcoming_change_name: "enable_solved_badges",
        event_data: {
          "Solved 1" => true,
          "Solved 2" => false,
          "Solved 3" => false,
          "Solved 4" => false,
        },
      )
      solved_badges.update_all(enabled: true)

      described_class.call(enabled: false)

      expect(Badge.find_by(name: "Solved 1").enabled).to eq(true)
      expect(Badge.where(name: ["Solved 2", "Solved 3", "Solved 4"], enabled: false).count).to eq(3)
    end

    it "does nothing when there is no snapshot" do
      solved_badges.update_all(enabled: true)

      described_class.call(enabled: false)

      expect(solved_badges.where(enabled: true).count).to eq(4)
    end
  end
end
