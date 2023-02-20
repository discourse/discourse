# frozen_string_literal: true

module Chat
  module Service
    # Used to react to various DiscourseEvents from chat/plugin.rb, and
    # determine which sub-service to call to handle these events. This class
    # should be called from the [Jobs::AutoJoinChannelMemberships] job,
    # rather than inline, since some of the operations may take some time.
    #
    # We only log the number of users removed based on the original event,
    # detailed logging has been intentionally left out for now, as admins
    # should be able to infer what happened to cause user removals from
    # channels from other staff action logs.
    #
    # @example
    #  Chat::Service::AutoRemoveMembershipEventHandler.call(
    #    event_type: :chat_allowed_groups_changed,
    #    event_data: { new_allowed_groups: "1|11" }
    #  )
    #
    class AutoRemoveMembershipEventHandler
      include Base

      # @!method call(event_type:, event_data:)
      #   @param [String|Symbol] event_type
      #   @param [Hash] event_data
      #   @return [Chat::Service::Base::Context]

      ALLOWED_EVENTS = %i[chat_allowed_groups_changed user_removed_from_group category_updated]

      contract
      step :handle_event

      class Contract
        attribute :event_type
        attribute :event_data

        before_validation { self.event_type = self.event_type.to_sym }

        validate :event_type_ok

        def event_type_ok
          return if ALLOWED_EVENTS.include?(self.event_type)
          errors.add(:event_type, "is invalid")
        end
      end

      private

      def handle_event(contract:, **)
        case contract.event_type
        when :chat_allowed_groups_changed
          result =
            Chat::Service::AutoRemove::HandleChatAllowedGroupsChange.call(**contract.event_data)
        when :user_removed_from_group
          result = Chat::Service::AutoRemove::HandleUserRemovedFromGroup.call(**contract.event_data)
        when :category_updated
          result = Chat::Service::AutoRemove::HandleCategoryUpdated.call(**contract.event_data)
        end

        fail!(result.context) if result.failure?

        if result.users_removed.positive?
          StaffActionLogger.new(Discourse.system_user).log_custom(
            "chat_auto_remove_membership",
            { users_removed: result.users_removed, event: contract.event_type },
          )
        end
      end
    end
  end
end
