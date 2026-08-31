# frozen_string_literal: true

RSpec.describe Jobs::Voice::CleanupEphemeralRooms do
  fab!(:stale_room) { Fabricate(:voice_ephemeral_room, last_occupied_at: 2.hours.ago) }

  it "reaps stale ephemeral rooms" do
    SiteSetting.voice_enabled = true
    room_id = stale_room.id

    described_class.new.execute({})

    expect(Voice::Room.exists?(room_id)).to eq(false)
  end

  it "does nothing while the plugin is disabled" do
    SiteSetting.voice_enabled = false

    described_class.new.execute({})

    expect(Voice::Room.exists?(stale_room.id)).to eq(true)
  end
end
