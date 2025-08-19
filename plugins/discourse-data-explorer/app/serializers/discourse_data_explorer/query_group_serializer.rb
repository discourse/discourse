# frozen_string_literal: true

module ::DiscourseDataExplorer
  class QueryGroupSerializer < ActiveModel::Serializer
    attributes :id, :group_id, :query_id, :bookmark

    def query_group_bookmark
      @query_group_bookmark ||= Bookmark.find_by(user: scope.user, bookmarkable: object)
    end

    def include_bookmark?
      query_group_bookmark.present?
    end

    def bookmark
      {
        id: query_group_bookmark.id,
        reminder_at: query_group_bookmark.reminder_at,
        name: query_group_bookmark.name,
        auto_delete_preference: query_group_bookmark.auto_delete_preference,
        bookmarkable_id: query_group_bookmark.bookmarkable_id,
        bookmarkable_type: query_group_bookmark.bookmarkable_type,
      }
    end
  end
end
