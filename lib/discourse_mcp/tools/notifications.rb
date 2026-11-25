# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class ListNotifications
      REQUIRED_SCOPES = [Scopes::CONTENT_READ].freeze
      CONTENT = {
        topics: :unenforced,
        private_messages: :enforced,
        categories: :unenforced,
        tags: :unenforced,
        exit_paths: :untouched,
      }.freeze
      # Chat content is delegated separately from forum content; this notification
      # type embeds the watched thread's root message text.
      CHAT_READ_SCOPE = "chat:read"
      CHAT_NOTIFICATION_TYPES = %i[chat_watched_thread].freeze
      OUTPUT_SCHEMA = OutputSchema.object(notifications: OutputSchema::OBJECT_ARRAY)

      # Mentions in a reviewable note carry the reviewable's id but no topic. When
      # the reviewable belongs to a personal message, the mention is filtered in
      # the query, so it can't take a place in the page. The data column is plain
      # text, so the id is matched rather than parsed as JSON.
      PRIVATE_REVIEWABLE_MENTION_SQL = <<~SQL
        notifications.notification_type = :mentioned
        AND EXISTS (
          SELECT 1
          FROM reviewables
          JOIN topics private_topics ON private_topics.id = reviewables.topic_id
          WHERE reviewables.id::text = substring(notifications.data from '"reviewable_id":\\s*"?([0-9]+)')
            AND private_topics.archetype = :private_message
        )
      SQL

      # A consolidated like counts likes on every post, personal messages
      # included, and only names one of them, so only the fields describing that
      # post and the actor are kept.
      CONSOLIDATED_LIKE_DATA_KEYS = %i[
        topic_title
        original_post_id
        original_post_type
        original_username
        revision_number
        display_username
        display_name
        username
      ].freeze

      # Consolidated notifications keep the title and post id of the notification
      # they replaced but carry no topic, so the topic join above can't see them.
      # One that names a topic is kept only when its post is outside personal
      # messages. Reviewable mentions are checked by their reviewable instead.
      TOPICLESS_PRIVATE_MESSAGE_SQL = <<~SQL
        notifications.topic_id IS NULL
        AND notifications.data LIKE '%"topic_title"%'
        AND notifications.data NOT LIKE '%"reviewable_id"%'
        AND NOT EXISTS (
          SELECT 1
          FROM posts public_posts
          JOIN topics public_topics ON public_topics.id = public_posts.topic_id
          WHERE public_posts.id::text = substring(notifications.data from '"original_post_id":\s*"?([0-9]+)')
            AND public_topics.archetype <> :private_message
        )
      SQL

      def self.call(arguments:, request_context:)
        limit = arguments.fetch("limit", 50).to_i.clamp(1, 100)
        notifications =
          Notification
            .where(user_id: request_context.user_id)
            .visible
            .includes(:topic)
            .order(id: :desc)
            .limit(limit)
        notifications = filter_chat_notifications_by_scope(notifications, request_context)
        if !request_context.has_scopes?(Scopes::PRIVATE_MESSAGES_READ)
          notifications =
            notifications
              .where.not(notification_type: Notification.types[:group_message_summary])
              .left_joins(:topic)
              .where("topics.id IS NULL OR topics.archetype <> ?", Archetype.private_message)
              .where.not(
                PRIVATE_REVIEWABLE_MENTION_SQL,
                mentioned: Notification.types[:mentioned],
                private_message: Archetype.private_message,
              )
              .where.not(TOPICLESS_PRIVATE_MESSAGE_SQL, private_message: Archetype.private_message)
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
        private_messages_denied = ToolHelpers.private_messages_denied?(request_context)
        serialized =
          notifications.map do |notification|
            json =
              NotificationSerializer.new(
                notification,
                scope: request_context.guardian,
                root: false,
              ).as_json
            if private_messages_denied &&
                 notification.notification_type == Notification.types[:liked_consolidated]
              json[:data] = json[:data].to_h.symbolize_keys.slice(*CONSOLIDATED_LIKE_DATA_KEYS)
            end
            json
          end
        ToolHelpers.text_and_structured(notifications: serialized)
      end

      # Applied to the relation so chat notifications never consume the caller's
      # page, and later pages cannot reveal them either.
      def self.filter_chat_notifications_by_scope(notifications, request_context)
        return notifications if request_context.has_scopes?(CHAT_READ_SCOPE)

        notifications.where.not(
          notification_type: CHAT_NOTIFICATION_TYPES.map { |type| Notification.types[type] },
        )
      end
      private_class_method :filter_chat_notifications_by_scope

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
