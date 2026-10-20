# frozen_string_literal: true

module Jobs
  class PublishRoomParticipants < ::Jobs::Scheduled
    every 1.minute
    sidekiq_options retry: false
    cluster_concurrency 1

    # Backstop that re-asserts full participant state so clients converge even
    # after missing a broadcast (page-load races, sleep/resume, message-bus
    # backlog gaps). It iterates rooms with recent membership activity rather
    # than scanning for participants keys in Redis: an emptied room's key is
    # gone, but its (empty) state still needs re-broadcasting for a while,
    # otherwise a single missed leave message shows ghosts until reload.
    def execute(args)
      return unless ::Live.enabled?

      provider_room_ids = ::Live::AgentManager.provider_room_ids
      room_ids = ::Live::ParticipantTracker.recently_active_room_ids | provider_room_ids

      # Auto live statuses have no ends_at, so a lapsed heartbeat must drop
      # the status the same way it drops the roster entry. Live-anywhere is
      # the keep criterion: a user mid-move between rooms is still live.
      live_user_ids =
        room_ids.flat_map { |room_id| ::Live::ParticipantTracker.user_ids(room_id) }.uniq
      ::Live::UserStatusManager.clear_stale_statuses(live_user_ids)

      return if room_ids.empty?

      remaining_provider_room_ids = provider_room_ids.to_set
      ::Live::Room
        .where(id: room_ids)
        .find_each do |room|
          remaining_provider_room_ids.delete(room.id)
          # Backstop for the pin-clear on last leave: a room that emptied
          # without one (crashed clients, missed leave) must not hold its
          # transport for the next call.
          if ::Live::ParticipantTracker.vacant?(room.id)
            # Agent cleanup survives expired pins and retries provider failures.
            ::Live::AgentManager.evict_agents_in_room!(room)
          else
            ::Live::AgentManager.reconcile(room)
          end
          ::Live::RoomBroadcaster.publish_participants(room)
        end

      # Provider cleanup must outlive the database row when deletion fails remotely.
      remaining_provider_room_ids.each do |room_id|
        ::Live::AgentManager.evict_agents_in_room!(::Live::Room.new(id: room_id))
      end
    end
  end
end
