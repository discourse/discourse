# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class ListNotifications
      REQUIRED_SCOPES = [Scopes::CONTENT_READ].freeze
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
        if !request_context.has_scopes?(Scopes::PRIVATE_MESSAGES_READ)
          notifications =
            notifications.left_joins(:topic).where(
              "topics.id IS NULL OR topics.archetype <> ?",
              Archetype.private_message,
            )
        end
        notifications =
          Notification.filter_inaccessible_topic_notifications(
            request_context.guardian,
            notifications,
          )
        notifications =
          Notification.filter_inaccessible_reviewable_notifications(
            request_context.guardian,
            notifications,
          )
        notifications = filter_reviewable_mentions_by_scope(notifications, request_context)
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

      # Reviewable mentions carry no topic, so the PM gate above never sees them;
      # hold them to the scopes the moderation tools require instead.
      def self.filter_reviewable_mentions_by_scope(notifications, request_context)
        reviewable_ids =
          notifications
            .select(&:reviewable_mention?)
            .map { |notification| notification.data_hash[:reviewable_id].to_i }
            .uniq
        return notifications if reviewable_ids.empty?

        allowed_ids =
          if request_context.has_scopes?(Scopes::MODERATION_READ)
            topic_id_by_reviewable_id =
              Reviewable.where(id: reviewable_ids).pluck(:id, :topic_id).to_h
            private_message_topic_ids =
              if request_context.has_scopes?(Scopes::PRIVATE_MESSAGES_READ)
                []
              else
                # Unscoped so trashed private messages stay hidden too.
                Topic
                  .unscoped
                  .where(
                    id: topic_id_by_reviewable_id.values.compact,
                    archetype: Archetype.private_message,
                  )
                  .pluck(:id)
              end
            topic_id_by_reviewable_id
              .reject { |_, topic_id| private_message_topic_ids.include?(topic_id) }
              .keys
              .to_set
          else
            Set.new
          end

        notifications.reject do |notification|
          notification.reviewable_mention? &&
            !allowed_ids.include?(notification.data_hash[:reviewable_id].to_i)
        end
      end
      private_class_method :filter_reviewable_mentions_by_scope
    end
  end
end
