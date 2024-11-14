# frozen_string_literal: true

module Chat
  module Action
    # All of the handlers that auto-remove users from chat
    # (under services/auto_remove) need to publish which users
    # were removed and from which channel, as well as logging
    # this in staff actions so it's obvious why these users were
    # removed.
    class PublishAutoRemovedUser < Service::ActionBase
      # @param [Symbol] event What caused the users to be removed,
      #   each handler will define this, e.g. category_updated, user_removed_from_group
      # @param [Hash] users_removed_map A hash with channel_id as its keys and an
      #   array of user_ids who were removed from the channel.
      option :event
      option :users_removed_map

      def call
        return if users_removed_map.empty?

        users_removed_map.each do |channel_id, all_user_ids|
          next if all_user_ids.empty?

          job_spacer = JobTimeSpacer.new

          all_user_ids.in_groups_of(1000, false) do |user_ids|
            job_spacer.enqueue(Jobs::Chat::KickUsersFromChannel, { channel_id:, user_ids: })
          end

          StaffActionLogger.new(Discourse.system_user).log_custom(
            "chat_auto_remove_membership",
            { users_removed: all_user_ids.size, channel_id:, event: },
          )
        end
      end
    end
  end
end
