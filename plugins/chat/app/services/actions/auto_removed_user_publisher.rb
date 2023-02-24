# frozen_string_literal: true

module Chat
  module Service
    module Actions
      class AutoRemovedUserPublisher
        def self.call(event_type:, users_removed_map:)
          return if users_removed_map.empty?

          users_removed_map.each do |channel_id, user_ids|
            job_spacer = JobTimeSpacer.new
            user_ids.in_groups_of(1000, false) do |user_id_batch|
              job_spacer.enqueue(
                :kick_users_from_channel,
                { channel_id: channel_id, user_ids: user_id_batch },
              )
            end

            if user_ids.any?
              StaffActionLogger.new(Discourse.system_user).log_custom(
                "chat_auto_remove_membership",
                { users_removed: user_ids.length, channel_id: channel_id, event: event_type },
              )
            end
          end
        end
      end
    end
  end
end
