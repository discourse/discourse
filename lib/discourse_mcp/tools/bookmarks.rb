# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class ListBookmarks
      REQUIRED_SCOPES = [Scopes::CONTENT_READ].freeze
      OUTPUT_SCHEMA = OutputSchema.object(bookmarks: OutputSchema::OBJECT_ARRAY)

      def self.call(arguments:, request_context:)
        bookmarks = Bookmark.where(user_id: request_context.user_id)
        if !request_context.has_scopes?(Scopes::PRIVATE_MESSAGES_READ)
          private_topic_ids = Topic.where(archetype: Archetype.private_message).select(:id)
          bookmarks =
            bookmarks
              .where.not(bookmarkable_type: "Topic", bookmarkable_id: private_topic_ids)
              .where.not(
                bookmarkable_type: "Post",
                bookmarkable_id: Post.where(topic_id: private_topic_ids).select(:id),
              )
        end
        bookmarks =
          bookmarks
            .includes(:bookmarkable)
            .order(updated_at: :desc)
            .limit(arguments.fetch("limit", 50).to_i.clamp(1, 100))
        values =
          bookmarks.filter_map do |bookmark|
            bookmarkable = bookmark.bookmarkable
            next if bookmarkable.blank? || !request_context.guardian.can_see?(bookmarkable)
            {
              id: bookmark.id,
              name: bookmark.name,
              reminder_at: bookmark.reminder_at&.iso8601,
              bookmarkable_type: bookmark.bookmarkable_type,
              bookmarkable_id: bookmark.bookmarkable_id,
            }
          end
        ToolHelpers.text_and_structured(bookmarks: values)
      end
    end
  end
end
