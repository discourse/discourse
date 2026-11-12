# frozen_string_literal: true

RSpec.describe Live::RoomDirectoryPreloader do
  fab!(:first_room, :live_room)
  fab!(:second_room, :live_room)
  fab!(:first_user, :user)
  fab!(:second_user, :user)

  before do
    SiteSetting.live_enabled = true
    Live::ParticipantTracker.add(first_room.id, first_user.id)
    Live::ParticipantTracker.add(first_room.id, second_user.id)
    Live::ParticipantTracker.add(second_room.id, first_user.id)
    Live::ParticipantTracker.update_metadata(first_room.id, first_user.id, muted: true)
    Live::ParticipantTracker.pin_transport!(first_room.id, "livekit")
    Live::ParticipantTracker.set_recording(
      first_room.id,
      egress_id: "EG_1",
      user_id: first_user.id,
      username: first_user.username,
      started_at: 123.0,
    )
  end

  after do
    Live::ParticipantTracker.clear(first_room.id)
    Live::ParticipantTracker.clear(second_room.id)
  end

  it "preloads live room state and participant users for the directory" do
    entries = described_class.preload([first_room, second_room])

    expect(entries[first_room.id].message_bus_last_id).to be_a(Integer)
    expect(entries[first_room.id].participant_users).to eq([first_user, second_user])
    expect(entries[first_room.id].participant_metadata).to eq(first_user.id => { muted: true })
    expect(entries[first_room.id].pinned_transport).to eq("livekit")
    expect(entries[first_room.id].recording).to eq(
      started_at: 123.0,
      started_by: {
        id: first_user.id,
        username: first_user.username,
      },
    )
    expect(entries[second_room.id].participant_users).to eq([first_user])
    expect(entries[second_room.id].recording).to be_nil
  end

  it "loads participant users in one query regardless of room count" do
    user_queries =
      track_sql_queries { described_class.preload([first_room, second_room]) }.grep(/FROM "users"/)

    expect(user_queries.size).to eq(1)
  end

  it "pipelines live room state in one Redis round trip" do
    MethodProfiler.ensure_discourse_instrumentation!
    MethodProfiler.start

    described_class.preload([first_room, second_room])
    profile = MethodProfiler.stop

    expect(profile.dig(:redis, :calls)).to eq(1)
  ensure
    MethodProfiler.clear
  end

  it "does no work for an empty directory" do
    expect(track_sql_queries { described_class.preload([]) }).to be_empty
    expect(described_class.preload([])).to eq({})
  end
end
