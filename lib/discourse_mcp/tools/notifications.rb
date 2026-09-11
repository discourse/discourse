# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class ListNotifications
      OUTPUT_SCHEMA = OutputSchema.object(notifications: OutputSchema::OBJECT_ARRAY)

      def self.call(arguments:, request_context:)
        limit = arguments.fetch("limit", 50).to_i.clamp(1, 100)
        notifications =
          Notification
            .where(user_id: request_context.user_id)
            .visible
            .includes(:topic)
            .order(id: :desc)
            .limit(limit)
        notifications =
          Notification.filter_inaccessible_topic_notifications(
            request_context.guardian,
            notifications,
          )
        notifications = Notification.filter_disabled_badge_notifications(notifications)
        notifications = Notification.populate_acting_user(notifications)
        serialized =
          notifications.map do |notification|
            NotificationSerializer.new(
              notification,
              scope: request_context.guardian,
              root: false,
            ).as_json
          end
        ToolHelpers.text_and_structured(notifications: serialized)
      end
    end
  end
end
