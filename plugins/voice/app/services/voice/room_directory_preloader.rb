# frozen_string_literal: true

module Voice
  class RoomDirectoryPreloader
    Entry =
      Data.define(
        :message_bus_last_id,
        :participant_users,
        :participant_metadata,
        :pinned_transport,
        :recording,
      )

    class << self
      def preload(rooms)
        new(rooms).preload
      end
    end

    def initialize(rooms)
      @rooms = rooms
    end

    def preload
      room_ids = @rooms.map(&:id)
      return {} if room_ids.empty?

      channels_by_room_id = room_ids.to_h { |room_id| [room_id, Voice.room_channel(room_id)] }
      last_ids = MessageBus.last_ids(*channels_by_room_id.values)
      room_states = Voice::ParticipantTracker.room_states(room_ids)
      users_by_id =
        User.where(id: room_states.values.flat_map(&:participant_ids).uniq).index_by(&:id)

      room_ids.to_h do |room_id|
        state = room_states.fetch(room_id)
        channel = channels_by_room_id.fetch(room_id)
        [
          room_id,
          Entry.new(
            message_bus_last_id: last_ids.fetch(channel),
            participant_users: state.participant_ids.filter_map { |user_id| users_by_id[user_id] },
            participant_metadata: state.participant_metadata,
            pinned_transport: state.pinned_transport,
            recording: Voice::RecordingManager.status_from_info(state.recording_info),
          ),
        ]
      end
    end
  end
end
