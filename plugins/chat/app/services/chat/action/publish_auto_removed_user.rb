# frozen_string_literal: true

module Chat
  module Action
    # All of the handlers that auto-remove users from chat
    # (under services/auto_remove) need to publish which users
    # were removed and from which channel, as well as logging
    # this in staff actions so it's obvious why these users were
    # removed.
    class PublishAutoRemovedUser < Service::ActionBase
      # @param [Symbol] event_type What caused the users to be removed,
      #   each handler will define this, e.g. category_updated, user_removed_from_group
      # @param [Hash] users_removed_map A hash with channel_id as its keys and an
      #   array of user_ids who were removed from the channel.
      option :event_type
      option :users_removed_map

      def call
        return if users_removed_map.empty?

        users_removed_map.each do |channel_id, user_ids|
          job_spacer = JobTimeSpacer.new
          user_ids.in_groups_of(1000, false) do |user_id_batch|
            job_spacer.enqueue(
              Jobs::Chat::KickUsersFromChannel,
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
