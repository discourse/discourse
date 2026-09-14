# frozen_string_literal: true

RSpec.describe Voice::ParticipantTracker do
  fab!(:room, :voice_room)
  fab!(:user1, :user)
  fab!(:user2, :user)

  before { SiteSetting.voice_enabled = true }

  after { described_class.clear(room.id) }

  describe ".add" do
    it "stores the user in the room's participant set" do
      described_class.add(room.id, user1.id)
      expect(described_class.user_ids(room.id)).to contain_exactly(user1.id)
    end

    it "ignores invalid user ids" do
      described_class.add(room.id, 0)
      described_class.add(room.id, -1)
      expect(described_class.user_ids(room.id)).to be_empty
    end
  end

  describe ".remove" do
    it "removes the user from participants and metadata" do
      described_class.add(room.id, user1.id)
      described_class.update_metadata(room.id, user1.id, { role: "participant" })

      described_class.remove(room.id, user1.id)

      expect(described_class.user_ids(room.id)).to be_empty
      expect(described_class.get_metadata(room.id, user1.id)).to eq({})
    end

    it "revokes the participant session" do
      described_class.add(room.id, user1.id)
      session_id = described_class.create_participant_session!(room.id, user1.id)

      described_class.remove(room.id, user1.id)

      expect(described_class.valid_participant_session?(room.id, user1.id, session_id)).to eq(false)
      expect(described_class.participant_session?(room.id, user1.id)).to eq(false)
    end
  end

  describe ".add_within_capacity" do
    it "admits users until the capacity is reached, then returns :full" do
      expect(described_class.add_within_capacity(room.id, user1.id, 2)).to eq(:added)
      expect(described_class.add_within_capacity(room.id, user2.id, 2)).to eq(:added)

      expect(described_class.add_within_capacity(room.id, 999, 2)).to eq(:full)
      expect(described_class.user_ids(room.id)).to contain_exactly(user1.id, user2.id)
    end

    it "refreshes an existing participant even when the room is full" do
      described_class.add_within_capacity(room.id, user1.id, 2)
      described_class.add_within_capacity(room.id, user2.id, 2)

      expect(described_class.add_within_capacity(room.id, user1.id, 2)).to eq(:existing)
      expect(described_class.user_ids(room.id)).to contain_exactly(user1.id, user2.id)
    end

    it "frees slots held by expired presence" do
      described_class.add_within_capacity(room.id, user1.id, 2)
      described_class.add_within_capacity(room.id, user2.id, 2)

      key = "#{described_class::KEY_NAMESPACE}:#{room.id}:participants"
      Discourse.redis.zadd(key, 1.hour.ago.to_f, user1.id)

      expect(described_class.add_within_capacity(room.id, 999, 2)).to eq(:added)
      expect(described_class.user_ids(room.id)).to contain_exactly(user2.id, 999)
    end

    it "never admits concurrent joiners past the capacity" do
      results =
        (1..10)
          .map do |candidate_id|
            Thread.new { described_class.add_within_capacity(room.id, candidate_id, 3) }
          end
          .map(&:value)

      expect(results.count(:added)).to eq(3)
      expect(results.count(:full)).to eq(7)
      expect(described_class.user_ids(room.id).size).to eq(3)
    end

    it "rejects invalid user ids" do
      expect(described_class.add_within_capacity(room.id, 0, 2)).to eq(:full)
      expect(described_class.user_ids(room.id)).to be_empty
    end
  end

  describe ".mark_left" do
    it "reports a recent departure until cleared" do
      described_class.mark_left(room.id, user1.id)

      expect(described_class.recently_left?(room.id, user1.id)).to eq(true)
      expect(described_class.recently_left?(room.id, user2.id)).to eq(false)

      described_class.clear_left(room.id, user1.id)

      expect(described_class.recently_left?(room.id, user1.id)).to eq(false)
    end
  end

  describe ".create_participant_session!" do
    it "mints a session that validates only for the exact id" do
      session_id = described_class.create_participant_session!(room.id, user1.id)

      expect(described_class.valid_participant_session?(room.id, user1.id, session_id)).to eq(true)
      expect(described_class.valid_participant_session?(room.id, user1.id, "other")).to eq(false)
      expect(described_class.valid_participant_session?(room.id, user1.id, nil)).to eq(false)
      expect(described_class.valid_participant_session?(room.id, user2.id, session_id)).to eq(false)
    end

    it "invalidates the previous session when a new one is minted" do
      first_session_id = described_class.create_participant_session!(room.id, user1.id)
      second_session_id = described_class.create_participant_session!(room.id, user1.id)

      expect(described_class.valid_participant_session?(room.id, user1.id, first_session_id)).to eq(
        false,
      )
      expect(
        described_class.valid_participant_session?(room.id, user1.id, second_session_id),
      ).to eq(true)
    end

    it "expires with the session TTL" do
      session_id = described_class.create_participant_session!(room.id, user1.id)

      key = "#{described_class::KEY_NAMESPACE}:#{room.id}:participant_session:#{user1.id}"
      expect(Discourse.redis.ttl(key)).to be_between(1, described_class.participant_session_ttl)

      Discourse.redis.del(key)

      expect(described_class.valid_participant_session?(room.id, user1.id, session_id)).to eq(false)
    end
  end

  describe ".raise_hand" do
    it "sets the raise timestamp and returns true on the first raise" do
      freeze_time do
        expect(described_class.raise_hand(room.id, user1.id)).to eq(true)

        # The timestamp round-trips through JSON, which can shave float digits.
        expect(described_class.get_metadata(room.id, user1.id)[:hand_raised_at]).to be_within(
          0.001,
        ).of(Time.now.to_f)
      end
    end

    it "returns false and keeps the original timestamp when already raised" do
      described_class.raise_hand(room.id, user1.id)
      original = described_class.get_metadata(room.id, user1.id)[:hand_raised_at]

      expect(described_class.raise_hand(room.id, user1.id)).to eq(false)
      expect(described_class.get_metadata(room.id, user1.id)[:hand_raised_at]).to eq(original)
    end
  end

  describe ".lower_hand" do
    it "clears the raised hand and returns true" do
      described_class.raise_hand(room.id, user1.id)

      expect(described_class.lower_hand(room.id, user1.id)).to eq(true)
      expect(described_class.get_metadata(room.id, user1.id)[:hand_raised_at]).to be_nil
    end

    it "returns false when the hand is not raised" do
      expect(described_class.lower_hand(room.id, user1.id)).to eq(false)
    end
  end

  describe ".pin_transport!" do
    it "pins the first transport and keeps it under a race" do
      expect(described_class.pin_transport!(room.id, "livekit")).to eq("livekit")

      # A concurrent joiner resolving differently must get the pinned value.
      expect(described_class.pin_transport!(room.id, "mesh")).to eq("livekit")
      expect(described_class.pinned_transport(room.id)).to eq("livekit")
    end

    it "expires on its own so a crashed room self-heals" do
      described_class.pin_transport!(room.id, "livekit")

      ttl = Discourse.redis.ttl("#{described_class::KEY_NAMESPACE}:#{room.id}:transport")
      expect(ttl).to be_between(1, SiteSetting.voice_participant_ttl_seconds * 2)
    end
  end

  describe ".pinned_transport" do
    it "returns nil when no pin exists" do
      expect(described_class.pinned_transport(room.id)).to be_nil
    end
  end

  describe ".refresh_transport_pin" do
    it "extends the pin's ttl" do
      key = "#{described_class::KEY_NAMESPACE}:#{room.id}:transport"
      described_class.pin_transport!(room.id, "livekit")
      Discourse.redis.expire(key, 1)

      described_class.refresh_transport_pin(room.id)

      expect(Discourse.redis.ttl(key)).to be > 1
    end
  end

  describe ".clear_transport_pin" do
    it "removes the pin" do
      described_class.pin_transport!(room.id, "mesh")

      described_class.clear_transport_pin(room.id)

      expect(described_class.pinned_transport(room.id)).to be_nil
    end
  end

  describe ".recently_active_room_ids" do
    it "includes rooms with recent membership changes, even once emptied" do
      described_class.add(room.id, user1.id)
      described_class.remove(room.id, user1.id)

      expect(described_class.recently_active_room_ids).to include(room.id)
    end

    it "prunes rooms whose last change is older than the safety window" do
      described_class.add(room.id, user1.id)
      Discourse.redis.zadd(described_class::RECENTLY_ACTIVE_ROOMS_KEY, 1.hour.ago.to_f, room.id)

      expect(described_class.recently_active_room_ids).not_to include(room.id)
      expect(Discourse.redis.zscore(described_class::RECENTLY_ACTIVE_ROOMS_KEY, room.id)).to be_nil
    end
  end

  describe ".user_ids" do
    it "returns only users with fresh heartbeats" do
      described_class.add(room.id, user1.id)
      described_class.add(room.id, user2.id)

      key = "#{described_class::KEY_NAMESPACE}:#{room.id}:participants"
      Discourse.redis.zadd(key, 1.hour.ago.to_f, user2.id)

      expect(described_class.user_ids(room.id)).to contain_exactly(user1.id)
    end

    it "returns empty when all heartbeats are stale" do
      described_class.add(room.id, user1.id)

      key = "#{described_class::KEY_NAMESPACE}:#{room.id}:participants"
      Discourse.redis.zadd(key, 1.hour.ago.to_f, user1.id)

      expect(described_class.user_ids(room.id)).to be_empty
    end
  end

  describe ".list" do
    it "returns User records for fresh participants only" do
      described_class.add(room.id, user1.id)
      described_class.add(room.id, user2.id)

      key = "#{described_class::KEY_NAMESPACE}:#{room.id}:participants"
      Discourse.redis.zadd(key, 1.hour.ago.to_f, user2.id)

      expect(described_class.list(room.id)).to contain_exactly(user1)
    end
  end

  describe ".last_heartbeat_at" do
    it "returns the time from metadata" do
      freeze_time do
        described_class.add(room.id, user1.id)
        described_class.update_metadata(room.id, user1.id, { last_heartbeat_at: Time.now.to_f })

        expect(described_class.last_heartbeat_at(room.id, user1.id)).to be_within(1.second).of(
          Time.now,
        )
      end
    end

    it "returns nil when no metadata exists" do
      expect(described_class.last_heartbeat_at(room.id, user1.id)).to be_nil
    end
  end

  describe ".clear" do
    it "removes all participants and metadata" do
      described_class.add(room.id, user1.id)
      described_class.update_metadata(room.id, user1.id, { role: "participant" })

      described_class.clear(room.id)

      expect(described_class.user_ids(room.id)).to be_empty
      expect(described_class.get_metadata(room.id, user1.id)).to eq({})
    end
  end

  describe ".room_states" do
    fab!(:other_room, :voice_room)

    after { described_class.clear(other_room.id) }

    it "loads participant, metadata, transport, and recording state for several rooms" do
      described_class.add(room.id, user1.id)
      described_class.update_metadata(room.id, user1.id, role: "moderator")
      described_class.pin_transport!(room.id, "livekit")
      described_class.set_recording(
        room.id,
        egress_id: "EG_1",
        user_id: user1.id,
        username: user1.username,
        started_at: 123.0,
      )
      described_class.add(other_room.id, user2.id)

      states = described_class.room_states([room.id, other_room.id])

      expect(states[room.id].to_h).to eq(
        participant_ids: [user1.id],
        participant_metadata: {
          user1.id => {
            role: "moderator",
          },
        },
        pinned_transport: "livekit",
        recording_info: {
          egress_id: "EG_1",
          user_id: user1.id,
          username: user1.username,
          started_at: 123.0,
        },
      )
      expect(states[other_room.id].to_h).to eq(
        participant_ids: [user2.id],
        participant_metadata: {
        },
        pinned_transport: nil,
        recording_info: nil,
      )
    end

    it "filters expired participants and repairs legacy participant keys" do
      participant_key = "#{described_class::KEY_NAMESPACE}:#{room.id}:participants"
      Discourse.redis.set(participant_key, user1.id)
      described_class.add(other_room.id, user2.id)
      Discourse.redis.zadd(
        "#{described_class::KEY_NAMESPACE}:#{other_room.id}:participants",
        1.hour.ago.to_f,
        user1.id,
      )

      states = described_class.room_states([room.id, other_room.id])

      expect(states.transform_values(&:participant_ids)).to eq(
        room.id => [],
        other_room.id => [user2.id],
      )
    end
  end

  describe ".participants_fingerprint" do
    it "is stable across calls and independent of insertion order" do
      described_class.add(room.id, user1.id)
      described_class.add(room.id, user2.id)

      fingerprint = described_class.participants_fingerprint(room.id)

      expect(described_class.participants_fingerprint(room.id)).to eq(fingerprint)
    end

    it "ignores last_heartbeat_at so plain heartbeats don't look like changes" do
      described_class.add(room.id, user1.id)
      described_class.update_metadata(room.id, user1.id, { last_heartbeat_at: 1.0 })
      before = described_class.participants_fingerprint(room.id)

      described_class.update_metadata(room.id, user1.id, { last_heartbeat_at: 2.0 })

      expect(described_class.participants_fingerprint(room.id)).to eq(before)
    end

    it "changes when a participant joins" do
      described_class.add(room.id, user1.id)
      before = described_class.participants_fingerprint(room.id)

      described_class.add(room.id, user2.id)

      expect(described_class.participants_fingerprint(room.id)).not_to eq(before)
    end

    it "changes when a participant's heartbeat goes stale" do
      described_class.add(room.id, user1.id)
      described_class.add(room.id, user2.id)
      before = described_class.participants_fingerprint(room.id)

      key = "#{described_class::KEY_NAMESPACE}:#{room.id}:participants"
      Discourse.redis.zadd(key, 1.hour.ago.to_f, user2.id)

      expect(described_class.participants_fingerprint(room.id)).not_to eq(before)
    end

    it "changes when a hand is raised and again when it is lowered" do
      described_class.add(room.id, user1.id)
      before_raise = described_class.participants_fingerprint(room.id)

      described_class.raise_hand(room.id, user1.id)
      after_raise = described_class.participants_fingerprint(room.id)
      expect(after_raise).not_to eq(before_raise)

      described_class.lower_hand(room.id, user1.id)
      expect(described_class.participants_fingerprint(room.id)).not_to eq(after_raise)
    end

    it "changes when rendered metadata such as idle_state changes" do
      described_class.add(room.id, user1.id)
      described_class.update_metadata(room.id, user1.id, { idle_state: "active" })
      before = described_class.participants_fingerprint(room.id)

      described_class.update_metadata(room.id, user1.id, { idle_state: "afk" })

      expect(described_class.participants_fingerprint(room.id)).not_to eq(before)
    end
  end

  describe ".swap_fingerprint" do
    it "stores the new fingerprint and returns the previous value" do
      expect(described_class.swap_fingerprint(room.id, "first")).to be_nil
      expect(described_class.swap_fingerprint(room.id, "second")).to eq("first")
    end
  end
end
