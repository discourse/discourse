# frozen_string_literal: true

##
# Allows us to query Bookmark records for lists. Used mainly
# in the user/activity/bookmarks page.

class BookmarkQuery
  def self.on_preload(&blk)
    (@preload ||= Set.new) << blk
  end

  def self.preload(bookmarks, object)
    preload_polymorphic_associations(bookmarks, object.guardian)
    @preload.each { |preload| preload.call(bookmarks, object) } if @preload
  end

  # These polymorphic associations are loaded to make the UserBookmarkListSerializer's
  # life easier, which conditionally chooses the bookmark serializer to use based
  # on the type, and we want the associations all loaded ahead of time to make
  # sure we are not doing N+1s.
  def self.preload_polymorphic_associations(bookmarks, guardian)
    Bookmark.registered_bookmarkables.each do |registered_bookmarkable|
      registered_bookmarkable.perform_preload(bookmarks, guardian)
    end
  end

  attr_reader :guardian, :count

  def initialize(user:, guardian: nil, search_term: nil, page: nil, per_page: nil)
    @user = user
    @search_term = search_term
    @guardian = guardian || Guardian.new(@user)
    @page = page ? page.to_i : 0
    @per_page = per_page ? per_page.to_i : 20
    @count = 0
  end

  def count_all
    queries = build_list_queries
    return 0 if queries.empty?
    Bookmark.from("(#{queries.join(" UNION ")}) AS bookmarks").count
  end

  def list_all(&blk)
    queries = build_list_queries
    return [] if queries.empty?

    results =
      Bookmark.from("(#{queries.join(" UNION ")}) AS bookmarks").order(
        Arel.sql(
          "(CASE WHEN bookmarks.pinned THEN 0 ELSE 1 END), bookmarks.reminder_at ASC, bookmarks.updated_at DESC",
        ),
      )

    @count = results.count

    results = results.offset(@page * @per_page) if @page.positive?
    results = blk&.call(results) || results
    results = results.limit(@per_page).to_a

    BookmarkQuery.preload(results, self)

    results
  end

  def unread_notifications(limit: 20)
    notifications =
      NotificationQuery.new(user: @user, guardian: @guardian).list(
        limit: [limit, 100].min,
        filter: :unread,
        types: [Notification.types[:bookmark_reminder]],
        prioritized: true,
      )

    bookmark_ids = notifications.filter_map { |n| n.data_hash[:bookmark_id] }

    bookmarks = Bookmark.where(user: @user, id: bookmark_ids)
    BookmarkQuery.preload(bookmarks, self)

    bookmarks_by_id = bookmarks.index_by(&:id)
    deleted_bookmarkables = load_deleted_bookmarkables(notifications, bookmarks_by_id)

    notifications.select do |n|
      can_see_notification_bookmark?(n, bookmarks_by_id, deleted_bookmarkables)
    end
  end

  private

  def build_list_queries
    Bookmark.registered_bookmarkables.filter_map do |bookmarkable|
      query = bookmarkable.perform_list_query(@user, @guardian)
      next if query.blank?
      query = apply_search_filter(bookmarkable, query) if @search_term.present?
      query.to_sql
    end
  end

  def apply_search_filter(bookmarkable, query)
    ts_query = Search.ts_query(term: @search_term)
    bookmarkable.perform_search_query(query, "%#{@search_term}%", ts_query)
  end

  def load_deleted_bookmarkables(notifications, bookmarks_by_id)
    notifications
      .select do |n|
        data = n.data_hash
        data[:bookmark_id].present? && data[:bookmarkable_type].present? &&
          !bookmarks_by_id[data[:bookmark_id]]
      end
      .group_by { |n| n.data_hash[:bookmarkable_type] }
      .transform_values do |notifs|
        ids = notifs.map { |n| n.data_hash[:bookmarkable_id] }
        type = notifs.first.data_hash[:bookmarkable_type]
        Bookmark.registered_bookmarkable_from_type(type).model.where(id: ids).index_by(&:id)
      end
  end

  def can_see_notification_bookmark?(notification, bookmarks_by_id, deleted_bookmarkables)
    data = notification.data_hash
    return false if data[:bookmark_id].nil?

    if bookmark = bookmarks_by_id[data[:bookmark_id]]
      Bookmark.registered_bookmarkable_from_type(bookmark.bookmarkable_type).can_see?(
        @guardian,
        bookmark,
      )
    else
      bookmarkable = deleted_bookmarkables.dig(data[:bookmarkable_type], data[:bookmarkable_id])
      bookmarkable &&
        Bookmark.registered_bookmarkable_from_type(data[:bookmarkable_type]).can_see_bookmarkable?(
          @guardian,
          bookmarkable,
        )
    end
  end
end
