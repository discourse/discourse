# frozen_string_literal: true

RSpec.describe Jobs::PublishRoomParticipants do
  subject(:job) { described_class.new }

  fab!(:room, :voice_room)
  fab!(:user1, :user)
  fab!(:user2, :user)

  before { SiteSetting.voice_enabled = true }

  it "publishes participants for rooms with active participants" do
    Voice::ParticipantTracker.add(room.id, user1.id)
    Voice::ParticipantTracker.add(room.id, user2.id)

    # Verify participants were added
    expect(Voice::ParticipantTracker.user_ids(room.id)).to contain_exactly(user1.id, user2.id)

    messages = MessageBus.track_publish { job.execute({}) }

    room_messages = messages.select { |m| m.channel == Voice.room_channel(room.id) }
    expect(room_messages.size).to eq(1)
    expect(room_messages.first.data[:type]).to eq("participants")
    expect(room_messages.first.data[:participants].map { |p| p[:id] }).to contain_exactly(
      user1.id,
      user2.id,
    )
  end

  it "reflects TTL-expired participants in broadcast" do
    Voice::ParticipantTracker.add(room.id, user1.id)
    Voice::ParticipantTracker.add(room.id, user2.id)

    # Set user2's heartbeat to a stale timestamp to simulate TTL expiration
    Discourse.redis.zadd(
      "#{Voice::ParticipantTracker::KEY_NAMESPACE}:#{room.id}:participants",
      1.hour.ago.to_f,
      user2.id,
    )

    messages = MessageBus.track_publish { job.execute({}) }

    room_messages = messages.select { |m| m.channel == Voice.room_channel(room.id) }
    expect(room_messages.size).to eq(1)
    expect(room_messages.first.data[:participants].map { |p| p[:id] }).to contain_exactly(user1.id)
  end

  it "does not publish for rooms without recent membership activity" do
    messages = MessageBus.track_publish { job.execute({}) }

    expect(messages).to be_empty
  end

  it "publishes an empty list for rooms that recently emptied" do
    Voice::ParticipantTracker.add(room.id, user1.id)
    Voice::ParticipantTracker.remove(room.id, user1.id)

    messages = MessageBus.track_publish { job.execute({}) }

    room_messages = messages.select { |m| m.channel == Voice.room_channel(room.id) }
    expect(room_messages.size).to eq(1)
    expect(room_messages.first.data[:participants]).to be_empty
  end

  it "stops publishing once a room's last activity leaves the safety window" do
    Voice::ParticipantTracker.add(room.id, user1.id)
    Voice::ParticipantTracker.remove(room.id, user1.id)
    Discourse.redis.zadd(
      Voice::ParticipantTracker::RECENTLY_ACTIVE_ROOMS_KEY,
      1.hour.ago.to_f,
      room.id,
    )

    messages = MessageBus.track_publish { job.execute({}) }

    expect(messages).to be_empty
  end

  it "handles rooms that no longer exist" do
    Voice::ParticipantTracker.add(99_999, user1.id)

    expect { job.execute({}) }.not_to raise_error
  end

  it "deletes an emptied livekit-pinned room from the SFU exactly once" do
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
    Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
    Voice::ParticipantTracker.add(room.id, user1.id)
    Voice::ParticipantTracker.remove(room.id, user1.id)
    stub = stub_request(:post, "https://livekit.example.com/twirp/livekit.RoomService/DeleteRoom")

    job.execute({})

    expect(stub).to have_been_requested.once
    expect(Voice::ParticipantTracker.pinned_transport(room.id)).to be_nil

    # The room stays in the recently-active sweep for a while; with the pin
    # gone, later sweeps must not keep re-deleting it.
    job.execute({})

    expect(stub).to have_been_requested.once
  end

  describe "stale status sweep" do
    before do
      SiteSetting.enable_user_status = true
      SiteSetting.voice_auto_status_enabled = true
    end

    # Statuses set within the sweep's grace window are skipped, so specs set
    # them in the past and re-add the live user's heartbeat after traveling.
    it "clears the status of a participant whose heartbeat lapsed" do
      Voice::ParticipantTracker.add(room.id, user1.id)
      Voice::ParticipantTracker.add(room.id, user2.id)
      Voice::UserStatusManager.set_voice_status(user1, room)
      Voice::UserStatusManager.set_voice_status(user2, room)

      freeze_time(1.minute.from_now)
      Voice::ParticipantTracker.add(room.id, user1.id)
      Discourse.redis.zadd(
        "#{Voice::ParticipantTracker::KEY_NAMESPACE}:#{room.id}:participants",
        1.hour.ago.to_f,
        user2.id,
      )

      job.execute({})

      expect(user1.reload.user_status).to be_present
      expect(user2.reload.user_status).to be_nil
    end

    it "clears lingering statuses of a room that fully emptied" do
      Voice::ParticipantTracker.add(room.id, user1.id)
      Voice::UserStatusManager.set_voice_status(user1, room)

      freeze_time(1.minute.from_now)
      Discourse.redis.zadd(
        "#{Voice::ParticipantTracker::KEY_NAMESPACE}:#{room.id}:participants",
        1.hour.ago.to_f,
        user1.id,
      )

      job.execute({})

      expect(user1.reload.user_status).to be_nil
    end

    it "keeps a user's status while they are live in another active room" do
      other_room = Fabricate(:voice_room)
      Voice::ParticipantTracker.add(room.id, user1.id)
      Voice::UserStatusManager.set_voice_status(user1, other_room)

      freeze_time(1.minute.from_now)
      Voice::ParticipantTracker.add(other_room.id, user1.id)
      Discourse.redis.zadd(
        "#{Voice::ParticipantTracker::KEY_NAMESPACE}:#{room.id}:participants",
        1.hour.ago.to_f,
        user1.id,
      )

      job.execute({})

      expect(user1.reload.user_status).to be_present
    end

    it "keeps a freshly set status even when the user is not yet live" do
      Voice::ParticipantTracker.add(room.id, user1.id)
      Voice::UserStatusManager.set_voice_status(user2, room)

      job.execute({})

      expect(user2.reload.user_status).to be_present
    end

    it "does not touch manually set statuses, even ones using Voice emojis" do
      Voice::ParticipantTracker.add(room.id, user1.id)
      user1.set_status!("Sleeping", "zzz")
      user2.set_status!("On vacation", "palm_tree")

      freeze_time(1.minute.from_now)

      job.execute({})

      expect(user1.reload.user_status.emoji).to eq("zzz")
      expect(user2.reload.user_status.emoji).to eq("palm_tree")
    end
  end

  it "does not publish when plugin is disabled" do
    Voice::ParticipantTracker.add(room.id, user1.id)

    SiteSetting.voice_enabled = false

    messages = MessageBus.track_publish { job.execute({}) }

    expect(messages).to be_empty
  end
end
