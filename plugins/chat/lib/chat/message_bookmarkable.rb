# frozen_string_literal: true

module Chat
  class MessageBookmarkable < BaseBookmarkable
    def self.model
      Chat::Message
    end

    def self.serializer
      Chat::UserChatMessageBookmarkSerializer
    end

    def self.preload_associations
      [:chat_channel]
    end

    def self.list_query(user, guardian)
      accessible_channel_ids = Chat::ChannelFetcher.all_secured_channel_ids(guardian)
      return if accessible_channel_ids.empty?
      user
        .bookmarks_of_type("Chat::Message")
        .joins(
          "INNER JOIN chat_messages ON chat_messages.id = bookmarks.bookmarkable_id
          AND chat_messages.deleted_at IS NULL
          AND bookmarks.bookmarkable_type = 'Chat::Message'",
        )
        .where("chat_messages.chat_channel_id IN (?)", accessible_channel_ids)
    end

    def self.search_query(bookmarks, query, ts_query, &bookmarkable_search)
      bookmarkable_search.call(bookmarks, "chat_messages.message ILIKE :q")
    end

    def self.validate_before_create(guardian, bookmarkable)
      if bookmarkable.blank? || !guardian.can_join_chat_channel?(bookmarkable.chat_channel)
        raise Discourse::InvalidAccess
      end
    end

    def self.reminder_handler(bookmark)
      send_reminder_notification(
        bookmark,
        data: {
          title:
            I18n.t(
              "chat.bookmarkable.notification_title",
              channel_name: bookmark.bookmarkable.chat_channel.title(bookmark.user),
            ),
          bookmarkable_url: bookmark.bookmarkable.url,
        },
      )
    end

    def self.reminder_conditions(bookmark)
      bookmark.bookmarkable.present? && bookmark.bookmarkable.chat_channel.present?
    end

    def self.can_see?(guardian, bookmark)
      guardian.can_join_chat_channel?(bookmark.bookmarkable.chat_channel)
    end

    def self.cleanup_deleted
      DB.query(<<~SQL, grace_time: 3.days.ago)
      DELETE FROM bookmarks b
      USING chat_messages cm
      WHERE b.bookmarkable_id = cm.id AND b.bookmarkable_type = 'Chat::Message'
      AND (cm.deleted_at < :grace_time)
    SQL
    end
  end
end
