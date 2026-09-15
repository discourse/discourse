# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class ListBookmarks
      OUTPUT_SCHEMA = OutputSchema.object(bookmarks: OutputSchema::OBJECT_ARRAY)

      def self.call(arguments:, request_context:)
        bookmarks =
          Bookmark
            .where(user_id: request_context.user_id)
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
