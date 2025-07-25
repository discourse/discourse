# frozen_string_literal: true

module ::DiscourseDataExplorer
  class QueryGroupBookmarkable < BaseBookmarkable
    def self.model
      QueryGroup
    end

    def self.serializer
      QueryGroupBookmarkSerializer
    end

    def self.preload_associations
      %i[data_explorer_queries groups]
    end

    def self.list_query(user, guardian)
      group_ids = []
      if !user.admin?
        group_ids = user.visible_groups.pluck(:id)
        return if group_ids.empty?
      end

      query =
        user
          .bookmarks_of_type("DiscourseDataExplorer::QueryGroup")
          .joins(
            "INNER JOIN data_explorer_query_groups ON data_explorer_query_groups.id = bookmarks.bookmarkable_id",
          )
          .joins(
            "LEFT JOIN data_explorer_queries ON data_explorer_queries.id = data_explorer_query_groups.query_id",
          )
      query = query.where("data_explorer_query_groups.group_id IN (?)", group_ids) if !user.admin?
      query
    end

    # Searchable only by data_explorer_queries name
    def self.search_query(bookmarks, query, ts_query, &bookmarkable_search)
      bookmarkable_search.call(bookmarks, "data_explorer_queries.name ILIKE :q")
    end

    def self.reminder_handler(bookmark)
      send_reminder_notification(
        bookmark,
        data: {
          title: bookmark.bookmarkable.query.name,
          bookmarkable_url:
            "/g/#{bookmark.bookmarkable.group.name}/reports/#{bookmark.bookmarkable.query.id}",
        },
      )
    end

    def self.reminder_conditions(bookmark)
      bookmark.bookmarkable.present?
    end

    def self.can_see?(guardian, bookmark)
      can_see_bookmarkable?(guardian, bookmark.bookmarkable)
    end

    def self.can_see_bookmarkable?(guardian, bookmarkable)
      return false if !bookmarkable.group
      guardian.user_is_a_member_of_group?(bookmarkable.group)
    end
  end
end
