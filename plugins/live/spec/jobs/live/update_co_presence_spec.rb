# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::Live::UpdateCoPresence do
  fab!(:room, :live_room)
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:bot) { Fabricate(:user, id: -1400) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_analytics_enabled = true
    SiteSetting.live_max_room_participants = 2
  end

  describe "#execute" do
    it "counts human pairs at capacity without counting agents" do
      [bot, user, other_user].each do |participant|
        Live::ParticipantTracker.add(room.id, participant.id)
      end

      described_class.new.execute({})

      expect(Live::CoPresence.pluck(:user_id_1, :user_id_2)).to contain_exactly(
        [user.id, other_user.id].sort,
      )
      expect(Live::CoPresence.sole.total_seconds).to eq(300)
    end
  end
end
