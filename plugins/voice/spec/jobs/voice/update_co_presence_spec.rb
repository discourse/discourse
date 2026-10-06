# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::Voice::UpdateCoPresence do
  fab!(:room, :voice_room)
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:bot) { Fabricate(:user, id: -1400) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_analytics_enabled = true
    SiteSetting.voice_max_room_participants = 2
  end

  describe "#execute" do
    it "counts human pairs at capacity without counting agents" do
      [bot, user, other_user].each do |participant|
        Voice::ParticipantTracker.add(room.id, participant.id)
      end

      described_class.new.execute({})

      expect(Voice::CoPresence.pluck(:user_id_1, :user_id_2)).to contain_exactly(
        [user.id, other_user.id].sort,
      )
      expect(Voice::CoPresence.sole.total_seconds).to eq(300)
    end
  end
end
