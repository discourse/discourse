# frozen_string_literal: true

module Voice
  class DirectoryBroadcaster
    class << self
      def broadcast(action:, room:)
        new(room, action).broadcast
      end
    end

    # Targets are captured eagerly so a broadcaster built before a destructive
    # action (see RoomsController#destroy) still knows who to notify once the
    # room's memberships are gone.
    def initialize(room, action)
      @room = room
      @action = action
      @targets =
        if room.public?
          Voice.public_room_message_bus_targets
        else
          { user_ids: room.member_ids }
        end
    end

    def broadcast
      # Ephemeral rooms never appear in the directory, so clients must not
      # receive index events that would splice them into it.
      return if room.ephemeral?

      # MessageBus rejects an empty user_ids target, and there is nobody to
      # notify anyway.
      return if targets[:user_ids] == []

      MessageBus.publish(
        Voice.room_index_channel,
        {
          type: action,
          room: Voice::RoomSerializer.new(room, scope: Guardian.new(nil), root: false).as_json,
        },
        **targets,
      )
    end

    private

    attr_reader :room, :action, :targets
  end
end
