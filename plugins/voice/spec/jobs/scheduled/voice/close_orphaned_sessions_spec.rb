# frozen_string_literal: true

RSpec.describe Jobs::Voice::CloseOrphanedSessions do
  subject(:job) { described_class.new }

  fab!(:room, :voice_room)
  fab!(:user1, :user)
  fab!(:user2, :user)

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_analytics_enabled = true
  end

  after { Voice::ParticipantTracker.clear(room.id) }

  def set_stale_participant(room, user, last_heartbeat:)
    key = "#{Voice::ParticipantTracker::KEY_NAMESPACE}:#{room.id}:participants"
    Discourse.redis.zadd(key, last_heartbeat.to_f, user.id)
    Voice::ParticipantTracker.update_metadata(
      room.id,
      user.id,
      { last_heartbeat_at: last_heartbeat.to_f },
    )
  end

  it "closes orphaned sessions using the last heartbeat timestamp" do
    session =
      Fabricate(:voice_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)

    last_heartbeat = 2.minutes.ago
    set_stale_participant(room, user1, last_heartbeat:)

    job.execute({})

    session.reload
    expect(session.left_at).to be_within(1.second).of(last_heartbeat)
  end

  it "falls back to Time.current when Redis data has expired" do
    session =
      Fabricate(:voice_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)

    freeze_time do
      job.execute({})

      session.reload
      expect(session.left_at).to be_within(1.second).of(Time.current)
    end
  end

  it "does not close sessions for users with fresh heartbeats" do
    session =
      Fabricate(:voice_session, user: user1, room: room, joined_at: 10.minutes.ago, left_at: nil)

    Voice::ParticipantTracker.add(room.id, user1.id)

    job.execute({})

    session.reload
    expect(session.left_at).to be_nil
  end

  it "cleans up stale Redis entries after closing" do
    Fabricate(:voice_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)

    set_stale_participant(room, user1, last_heartbeat: 2.minutes.ago)

    job.execute({})

    expect(Voice::ParticipantTracker.get_metadata(room.id, user1.id)).to eq({})
  end

  it "closes stale user sessions while keeping active users untouched" do
    stale_session =
      Fabricate(:voice_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)
    active_session =
      Fabricate(:voice_session, user: user2, room: room, joined_at: 50.minutes.ago, left_at: nil)

    set_stale_participant(room, user1, last_heartbeat: 2.minutes.ago)
    Voice::ParticipantTracker.add(room.id, user2.id)

    job.execute({})

    expect(stale_session.reload.left_at).to be_present
    expect(active_session.reload.left_at).to be_nil
  end

  it "closes sessions whose room has been deleted" do
    deleted_room = Fabricate(:voice_room)
    session =
      Fabricate(
        :voice_session,
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
    SiteSetting.voice_enabled = false
    session =
      Fabricate(:voice_session, user: user1, room: room, joined_at: 50.minutes.ago, left_at: nil)

    job.execute({})

    expect(session.reload.left_at).to be_nil
  end
end
