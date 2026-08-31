# frozen_string_literal: true
require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"

RSpec.describe Voice::DefaultRoomSeeder do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
    end
  end

  before { wipe_rooms! }

  it "creates a Watercooler room when voice is enabled and no rooms exist" do
    SiteSetting.voice_enabled = true
    wipe_rooms!

    expect { described_class.ensure! }.to change { Voice::Room.count }.by(1)

    room = Voice::Room.first
    expect(room.name).to eq("Watercooler")
    expect(room.public).to eq(true)
  end

  it "does nothing if voice is disabled" do
    SiteSetting.voice_enabled = false

    expect { described_class.ensure! }.not_to change { Voice::Room.count }
  end

  it "still seeds when only ephemeral rooms exist" do
    SiteSetting.voice_enabled = true
    wipe_rooms!
    Fabricate(:voice_ephemeral_room, creator: Fabricate(:admin))

    expect { described_class.ensure! }.to change { Voice::Room.persistent.count }.by(1)
  end

  it "does nothing if rooms already exist" do
    SiteSetting.voice_enabled = true
    wipe_rooms!
    Fabricate(:voice_room, name: "Existing", creator: Fabricate(:admin))

    expect { described_class.ensure! }.not_to change { Voice::Room.count }
  end

  def wipe_rooms!
    Voice::RoomMembership.delete_all
    Voice::Room.delete_all
  end
end
