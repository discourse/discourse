# frozen_string_literal: true

module Voice
  # Backend API for ephemeral rooms: short-lived rooms created by other
  # features (a direct call between two users, a scheduled event's stage)
  # rather than by a user filling in the room form. They never appear in the
  # directory or any other discovery surface — whoever creates one is
  # responsible for surfacing it — and they are reaped automatically once
  # they have sat empty past the configured TTL.
  class EphemeralRoomManager
    # Live (not yet reaped) ephemeral rooms one user can have outstanding at a
    # time; caps how much room state repeated call attempts can accumulate
    # before the TTL cleanup runs.
    MAX_LIVE_ROOMS_PER_CREATOR = 10

    # Inviting into a room is a moderator ability, so `moderators` is how a
    # consumer makes the parties peers (a direct call, where either side may
    # pull someone else in), while `members` fits an audience invited to a
    # room someone else runs.
    def self.create!(creator:, name:, members: [], moderators: [], **attrs)
      room = nil

      # The count and create must not be raceable, or concurrent call
      # attempts could blow past the cap.
      DistributedMutex.synchronize("voice-ephemeral-rooms-#{creator.id}") do
        if Voice::Room.ephemeral.where(creator_id: creator.id).count >= MAX_LIVE_ROOMS_PER_CREATOR
          raise Discourse::InvalidAccess.new(
                  :voice_ephemeral_room_limit,
                  nil,
                  custom_message: "voice.errors.ephemeral_room_limit",
                )
        end

        room =
          Voice::Room.create!(
            ephemeral: true,
            creator: creator,
            name: name,
            last_occupied_at: Time.current,
            **attrs,
          )
      end

      # The creator already holds a moderator membership from the model hook.
      moderators.each do |user|
        next if user.id == creator.id
        room.room_memberships.create!(user: user, role: RoomMembership::ROLE_MODERATOR)
      end

      members.each do |user|
        next if user.id == creator.id
        room.room_memberships.find_or_create_by!(user: user)
      end

      room
    end

    # Occupied rooms get their clock reset; rooms empty past the TTL are
    # destroyed. The TTL (rather than delete-on-empty) tolerates the gap
    # between creation and the first join, and a call where everyone's
    # presence briefly lapses at once.
    def self.cleanup!
      ttl = SiteSetting.voice_ephemeral_room_ttl_minutes.minutes

      Voice::Room.ephemeral.find_each do |room|
        if Voice::ParticipantTracker.user_ids(room.id).any?
          room.update_column(:last_occupied_at, Time.current)
        elsif (room.last_occupied_at || room.created_at) < ttl.ago
          destroy!(room)
        end
      end
    end

    def self.destroy!(room)
      # Guards consumers holding a stale reference: a persistent room must
      # never be torn down through the ephemeral lifecycle.
      raise Discourse::InvalidParameters.new(:room) unless room.ephemeral?

      room.destroy!
      Voice::Livekit::RoomServiceClient.delete_room(room)
      Voice::ParticipantTracker.clear(room.id)
    end
  end
end
