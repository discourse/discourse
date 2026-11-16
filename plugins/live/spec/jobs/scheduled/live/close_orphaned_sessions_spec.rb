# frozen_string_literal: true

RSpec.describe Jobs::Live::CloseOrphanedSessions do
  subject(:job) { described_class.new }

  fab!(:room, :live_room)
  fab!(:user1, :user)
  fab!(:user2, :user)

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_analytics_enabled = true
  end

  after { Live::ParticipantTracker.clear(room.id) }

  def set_stale_participant(room, user, last_heartbeat:)
    key = "#{Live::ParticipantTracker::KEY_NAMESPACE}:#{room.id}:participants"
    Discourse.redis.zadd(key, last_heartbeat.to_f, user.id)
    Live::ParticipantTracker.update_metadata(
      room.id,
      user.id,
      { last_heartbeat_at: last_heartbeat.to_f },
    )
  end

  it "closes orphaned sessions using the last heartbeat timestamp" do
    session =
      Fabricate(:live_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)

    last_heartbeat = 2.minutes.ago
    set_stale_participant(room, user1, last_heartbeat:)

    job.execute({})

    session.reload
    expect(session.left_at).to be_within(1.second).of(last_heartbeat)
  end

  it "falls back to Time.current when Redis data has expired" do
    session =
      Fabricate(:live_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)

    freeze_time do
      job.execute({})

      session.reload
      expect(session.left_at).to be_within(1.second).of(Time.current)
    end
  end

  it "does not close sessions for users with fresh heartbeats" do
    session =
      Fabricate(:live_session, user: user1, room: room, joined_at: 10.minutes.ago, left_at: nil)

    Live::ParticipantTracker.add(room.id, user1.id)

    job.execute({})

    session.reload
    expect(session.left_at).to be_nil
  end

  it "keeps sessions open while a lapsed participant can still resume" do
    session =
      Fabricate(:live_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)

    set_stale_participant(room, user1, last_heartbeat: 2.minutes.ago)
    Live::ParticipantTracker.create_participant_session!(room.id, user1.id)

    job.execute({})

    expect(session.reload.left_at).to be_nil
  end

  it "cleans up stale Redis entries after closing" do
    Fabricate(:live_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)

    set_stale_participant(room, user1, last_heartbeat: 2.minutes.ago)

    job.execute({})

    expect(Live::ParticipantTracker.get_metadata(room.id, user1.id)).to eq({})
  end

  it "ends agent participation when the final human session expires" do
    bot = Fabricate(:user, id: -1400)
    session =
      Fabricate(:live_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)
    set_stale_participant(room, user1, last_heartbeat: 2.minutes.ago)
    Live::ParticipantTracker.add(room.id, bot.id)
    Live::ParticipantTracker.pin_transport!(room.id, "mesh")

    job.execute({})

    expect(session.reload.left_at).to be_present
    expect(Live::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    expect(Live::ParticipantTracker.pinned_transport(room.id)).to be_nil
  end

  it "closes stale user sessions while keeping active users untouched" do
    stale_session =
      Fabricate(:live_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)
    active_session =
      Fabricate(:live_session, user: user2, room: room, joined_at: 50.minutes.ago, left_at: nil)

    set_stale_participant(room, user1, last_heartbeat: 2.minutes.ago)
    Live::ParticipantTracker.add(room.id, user2.id)

    job.execute({})

    expect(stale_session.reload.left_at).to be_present
    expect(active_session.reload.left_at).to be_nil
  end

  it "closes sessions whose room has been deleted" do
    deleted_room = Fabricate(:live_room)
    session =
      Fabricate(
        :live_session,
        user: user1,
        room: deleted_room,
        joined_at: 50.minutes.ago,
        left_at: nil,
      )
    deleted_room.destroy!

    freeze_time do
      job.execute({})

      expect(session.reload.left_at).to be_within(1.second).of(Time.current)
    end
  end

  it "does nothing when plugin is disabled" do
    SiteSetting.live_enabled = false
    session =
      Fabricate(:live_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)

    job.execute({})

    expect(session.reload.left_at).to be_nil
  end
end
