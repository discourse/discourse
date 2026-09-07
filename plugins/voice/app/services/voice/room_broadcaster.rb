# frozen_string_literal: true

module Voice
  class RoomBroadcaster
    def self.publish_participants(room)
      new(room).publish_participants
    end

    def self.publish_participants_if_changed(room)
      new(room).publish_participants_if_changed
    end

    def self.publish_kick(room, user_id)
      new(room).publish_kick(user_id)
    end

    def self.publish_role_change(room, user_id, new_role)
      new(room).publish_role_change(user_id, new_role)
    end

    def self.publish_hand_raise(room, user_id, raised:, raised_at: nil, reason: nil)
      new(room).publish_hand_raise(user_id, raised: raised, raised_at: raised_at, reason: reason)
    end

    # Someone in the room started ringing `user` — lets open room pages show
    # a pending tile for them without refetching the room.
    def self.publish_ringing(room, user, notified_at:)
      new(room).publish_room(
        type: "ringing",
        user: BasicUserSerializer.new(user, scope: Guardian.new(nil), root: false).as_json,
        notified_at: notified_at,
      )
    end

    def initialize(room)
      @room = room
    end

    def publish_participants(fingerprint: nil)
      guardian = Guardian.new(nil)
      all_metadata = Voice::ParticipantTracker.get_all_metadata(room.id)
      users = Voice::ParticipantTracker.list(room.id)
      entitlements = Voice::MediaEntitlements.for_users(room, users)
      payload = {
        type: "participants",
        room_id: room.id,
        participants:
          users.map do |user|
            BasicUserSerializer
              .new(user, scope: guardian, root: false)
              .as_json
              .merge(all_metadata[user.id] || {})
              .merge(entitlements[user.id] || Voice::MediaEntitlements::NONE)
          end,
      }

      MessageBus.publish(Voice.room_channel(room.id), payload, **room_message_bus_targets)

      # Keep the stored fingerprint in sync so the heartbeat backstop doesn't
      # redundantly re-broadcast the state we just sent.
      Voice::ParticipantTracker.update_fingerprint(room.id, fingerprint)
    end

    # Backstop for ghosts left by abrupt disconnects (refresh, tab close,
    # crash) that never sent a clean leave. Called on every heartbeat: it
    # compares the live membership/state against the last broadcast and emits a
    # single participants broadcast when — and only when — something changed.
    def publish_participants_if_changed
      fingerprint = Voice::ParticipantTracker.participants_fingerprint(room.id)
      previous = Voice::ParticipantTracker.swap_fingerprint(room.id, fingerprint)
      return if previous == fingerprint

      publish_participants(fingerprint: fingerprint)
    end

    def publish_room(payload)
      MessageBus.publish(
        Voice.room_channel(room.id),
        payload.merge(room_id: room.id),
        **room_message_bus_targets,
      )
    end

    def publish_kick(user_id)
      MessageBus.publish(
        Voice.room_channel(room.id),
        { type: "kicked", room_id: room.id },
        user_ids: [user_id],
      )
    end

    def publish_role_change(user_id, new_role)
      participant_ids = Voice::ParticipantTracker.user_ids(room.id)
      return if participant_ids.empty?

      MessageBus.publish(
        Voice.room_channel(room.id),
        { type: "role_change", room_id: room.id, user_id: user_id, role: new_role },
        user_ids: participant_ids,
      )
    end

    # Lightweight event alongside the authoritative participants broadcast, so
    # clients can toast on raises/dismissals without diffing rosters.
    def publish_hand_raise(user_id, raised:, raised_at: nil, reason: nil)
      participant_ids = Voice::ParticipantTracker.user_ids(room.id)
      return if participant_ids.empty?

      MessageBus.publish(
        Voice.room_channel(room.id),
        {
          type: "hand_raise",
          room_id: room.id,
          user_id: user_id,
          raised: raised,
          raised_at: raised_at,
          reason: reason,
        },
        user_ids: participant_ids,
      )
    end

    private

    attr_reader :room

    def room_message_bus_targets
      targets = room.message_bus_targets
      # An untargeted publish already reaches everyone; merging user_ids into
      # it would restrict delivery to just those users.
      return targets if targets.blank?

      participant_ids = Voice::ParticipantTracker.user_ids(room.id)
      return targets if participant_ids.empty?

      targets.merge(user_ids: Array(targets[:user_ids] || []) | participant_ids)
    end
  end
end
