# frozen_string_literal: true

module Chat
  module Service
    class AutoRemoveMembershipEventHandler
      include Base

      ALLOWED_EVENTS = %i[chat_allowed_groups_changed user_removed_from_group category_updated]

      contract
      policy :validate_event_type
      step :handle_event

      class Contract
        attribute :event_type
        attribute :event_data
      end

      private

      def validate_event_type(contract:, **)
        ALLOWED_EVENTS.include?(contract.event_type)
      end

      def handle_event(contract:, **)
        case contract.event_type
        when :chat_allowed_groups_changed
          result = Chat::Service::AutoRemove::OutsideChatAllowedGroups.call(**contract.event_data)
        when :user_removed_from_group
          result = Chat::Service::AutoRemove::UserRemovedFromGroup.call(**contract.event_data)
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
