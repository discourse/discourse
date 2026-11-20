# frozen_string_literal: true
require "rails_helper"

RSpec.describe Live::DefaultRoomSeeder do
  before { wipe_rooms! }

  it "creates a Watercooler room when live is enabled and no rooms exist" do
    SiteSetting.live_enabled = true
    wipe_rooms!

    expect { described_class.ensure! }.to change { Live::Room.count }.by(1)

    room = Live::Room.first
    expect(room.name).to eq("Watercooler")
    expect(room.public).to eq(true)
  end

  it "does nothing if live is disabled" do
    SiteSetting.live_enabled = false

    expect { described_class.ensure! }.not_to change { Live::Room.count }
  end

  it "still seeds when only ephemeral rooms exist" do
    SiteSetting.live_enabled = true
    wipe_rooms!
    Fabricate(:live_ephemeral_room, creator: Fabricate(:admin))

    expect { described_class.ensure! }.to change { Live::Room.persistent.count }.by(1)
  end

  it "does nothing if rooms already exist without checking pending migrations" do
    SiteSetting.live_enabled = true
    wipe_rooms!
    Fabricate(:live_room, name: "Existing", creator: Fabricate(:admin))

    described_class.ensure!
    queries = track_sql_queries { described_class.ensure! }

    expect(Live::Room.count).to eq(1)
    expect(queries.grep(/pg_class|schema_migrations/)).to be_empty
  end

  def wipe_rooms!
    Live::RoomMembership.delete_all
    Live::Room.delete_all
  end
end
