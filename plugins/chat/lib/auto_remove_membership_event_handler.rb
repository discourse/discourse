# frozen_string_literal: true

module Chat
  class AutoRemoveMembershipEventHandler
    ALLOWED_EVENTS = %i[chat_allowed_groups_changed user_removed_from_group category_updated]

    def initialize(event_type:, event_data:)
      @event_type = event_type
      @event_data = event_data
    end

    def call!
      validate_event!
      handle_event
    end

    private

    def validate_event!
      if !ALLOWED_EVENTS.include?(@event_type)
        raise StandardError.new("Invalid event, allowed events are #{ALLOWED_EVENTS.join(",")}")
      end
    end

    def handle_event
      case @event_type
      when :chat_allowed_groups_changed
        # any users who are _not_ in these groups
        # and who are _not_staff
        # should be de-stroyed
        users =
          User
            .join("LEFT JOIN group_users ON group_users.user_id = users.id")
            .real
            .activated
            .not_suspended
            .not_staged
            .where.not(admin: true, moderator: true)
            .where(
              "group_users.id IS NULL AND group_users.group_id IN (?)",
              SiteSetting.chat_allowed_groups_map,
            )
            .distinct
            .pluck(:user_id)

        UserChatChannelMembership.where(user_id: users).delete_all
      when :user_removed_from_group
      when :category_updated
      end
    end
  end
end
