# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class ListBookmarks
      REQUIRED_SCOPES = [Scopes::CONTENT_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema.object(bookmarks: OutputSchema::OBJECT_ARRAY)

      def self.call(arguments:, request_context:)
        bookmarks = Bookmark.where(user_id: request_context.user_id)
        if !request_context.has_scopes?(Scopes::PRIVATE_MESSAGES_READ)
          bookmarks = ToolHelpers.without_private_message_bookmarks(bookmarks)
        end
        bookmarks = allowed_bookmarks(bookmarks, request_context.content_policy)
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

      # While a rule is active, only bookmarks on topics and posts the policy
      # allows are listed. Other bookmarkable types can't be judged, so they're
      # left out.
      def self.allowed_bookmarks(bookmarks, policy)
        condition = policy.topic_condition("mcp_bookmark_topics")
        return bookmarks if condition.nil?

        bookmarks.where(<<~SQL.squish, topic: "Topic", post: "Post")
          (
            bookmarks.bookmarkable_type = :topic AND EXISTS (
              SELECT 1 FROM topics mcp_bookmark_topics
              WHERE mcp_bookmark_topics.id = bookmarks.bookmarkable_id AND #{condition}
            )
          ) OR (
            bookmarks.bookmarkable_type = :post AND EXISTS (
              SELECT 1
              FROM posts mcp_bookmark_posts
              JOIN topics mcp_bookmark_topics ON mcp_bookmark_topics.id = mcp_bookmark_posts.topic_id
              WHERE mcp_bookmark_posts.id = bookmarks.bookmarkable_id AND #{condition}
            )
          )
        SQL
      end
      private_class_method :allowed_bookmarks
    end
  end
end
