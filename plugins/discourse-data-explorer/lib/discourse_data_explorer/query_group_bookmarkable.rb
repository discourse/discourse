# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryGroupBookmarkable < BaseBookmarkable
    class << self
      def model
        QueryGroup
      end

      def serializer
        QueryGroupBookmarkSerializer
      end

      def preload_associations
        %i[data_explorer_queries groups]
      end

      def list_query(user, guardian)
        admin = user.admin?
        group_ids = []
        if !admin
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
        if !admin
          query = query.where("data_explorer_query_groups.group_id IN (?)", group_ids)
          query = query.where("data_explorer_queries.hidden = false")
        end
        query
      end

      # Searchable only by data_explorer_queries name
      def search_query(bookmarks, query, ts_query, &bookmarkable_search)
        bookmarkable_search.call(bookmarks, "data_explorer_queries.name ILIKE ?")
      end

      def validate_before_create(guardian, bookmarkable)
        if bookmarkable.blank? || !can_see_bookmarkable?(guardian, bookmarkable)
          raise Discourse::InvalidAccess
        end
      end

      def reminder_handler(bookmark)
        send_reminder_notification(
          bookmark,
          data: {
            title: bookmark.bookmarkable.query.name,
            bookmarkable_url:
              "/g/#{bookmark.bookmarkable.group.name}/reports/#{bookmark.bookmarkable.query.id}",
          },
        )
      end

      def reminder_conditions(bookmark)
        bookmark.bookmarkable.present? && can_see?(bookmark.user.guardian, bookmark)
      end

      def can_see?(guardian, bookmark)
        can_see_bookmarkable?(guardian, bookmark.bookmarkable)
      end

      def can_see_bookmarkable?(guardian, bookmarkable)
        if bookmarkable.blank? || bookmarkable.group.blank? || bookmarkable.query.blank?
          return false
        end
        return true if guardian.is_admin?

        !bookmarkable.query.hidden? &&
          guardian.group_and_user_can_access_query?(bookmarkable.group, bookmarkable.query)
      end
    end
  end
end
