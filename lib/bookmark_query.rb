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

  attr_reader :guardian

  def initialize(user:, guardian: nil, search_term: nil, page: nil, per_page: nil)
    @user = user
    @search_term = search_term
    @guardian = guardian || Guardian.new(@user)
    @page = page ? page.to_i : 0
    @per_page = per_page ? per_page.to_i : 20
  end

  def count_all
    queries = list_queries
    return 0 if queries.empty?
    Bookmark.from("(#{queries.join(" UNION ")}) AS bookmarks").count
  end

  def list_all(&blk)
    queries = list_queries
    return [] if queries.empty?

    results =
      Bookmark.from("(#{queries.join(" UNION ")}) AS bookmarks").order(
        Arel.sql(
          "(CASE WHEN bookmarks.pinned THEN 0 ELSE 1 END), bookmarks.reminder_at ASC, bookmarks.updated_at DESC",
        ),
      )

    results = results.offset(@page * @per_page) if @page.positive?
    results = blk&.call(results) || results
    results = results.limit(@per_page).to_a

    BookmarkQuery.preload(results, self)

    results
  end

  private

  def list_queries
    @list_queries ||= build_list_queries
  end

  def build_list_queries
    Bookmark.registered_bookmarkables.filter_map do |bookmarkable|
      query = bookmarkable.perform_list_query(@user, @guardian)
      next if query.nil?
      query = apply_search_filter(bookmarkable, query) if @search_term.present?
      query.to_sql
    end
  end

  def apply_search_filter(bookmarkable, query)
    ts_query = Search.ts_query(term: @search_term)
    bookmarkable.perform_search_query(query, "%#{@search_term}%", ts_query)
  end
end
