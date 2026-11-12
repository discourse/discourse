# frozen_string_literal: true

RSpec.describe Jobs::Live::CleanupEphemeralRooms do
  fab!(:stale_room) { Fabricate(:live_ephemeral_room, last_occupied_at: 2.hours.ago) }

  it "reaps stale ephemeral rooms" do
    SiteSetting.live_enabled = true
    room_id = stale_room.id

    described_class.new.execute({})

    expect(Live::Room.exists?(room_id)).to eq(false)
  end

  it "does nothing while the plugin is disabled" do
    SiteSetting.live_enabled = false

    described_class.new.execute({})

    expect(Live::Room.exists?(stale_room.id)).to eq(true)
  end
end
