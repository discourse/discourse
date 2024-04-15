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

  def list_all(&blk)
    ts_query = @search_term.present? ? Search.ts_query(term: @search_term) : nil
    search_term_wildcard = @search_term.present? ? "%#{@search_term}%" : nil

    queries =
      Bookmark
        .registered_bookmarkables
        .map do |bookmarkable|
          interim_results = bookmarkable.perform_list_query(@user, @guardian)

          # this could occur if there is some security reason that the user cannot
          # access the bookmarkables that they have bookmarked, e.g. if they had 1 bookmark
          # on a topic and that topic was moved into a private category
          next if interim_results.blank?

          if @search_term.present?
            interim_results =
              bookmarkable.perform_search_query(interim_results, search_term_wildcard, ts_query)
          end

          # this is purely to make the query easy to read and debug, otherwise it's
          # all mashed up into a massive ball in MiniProfiler :)
          "---- #{bookmarkable.model} bookmarkable ---\n\n #{interim_results.to_sql}"
        end
        .compact

    # same for interim results being blank, the user might have been locked out
    # from all their various bookmarks, in which case they will see nothing and
    # no further pagination/ordering/etc is required
    return [] if queries.empty?

    union_sql = queries.join("\n\nUNION\n\n")
    results = Bookmark.select("bookmarks.*").from("(\n\n#{union_sql}\n\n) as bookmarks")
    results =
      results.order(
        "(CASE WHEN bookmarks.pinned THEN 0 ELSE 1 END),
        bookmarks.reminder_at ASC,
        bookmarks.updated_at DESC",
      )

    @count = results.count

    results = results.offset(@page * @per_page) if @page.positive?

    if updated_results = blk&.call(results)
      results = updated_results
    end

    results = results.limit(@per_page).to_a

    BookmarkQuery.preload(results, self)
    results
  end

  def unread_notifications(limit: 20)
    reminder_notifications =
      Notification
        .for_user_menu(@user.id, limit: [limit, 100].min)
        .unread
        .where(notification_type: Notification.types[:bookmark_reminder])

    reminder_bookmark_ids = reminder_notifications.map { |n| n.data_hash[:bookmark_id] }.compact

    # We preload associations like we do above for the list to avoid
    # N1s in the can_see? guardian calls for each bookmark.
    bookmarks = Bookmark.where(user: @user, id: reminder_bookmark_ids)
    BookmarkQuery.preload(bookmarks, self)

    # Any bookmarks that no longer exist, we need to find the associated
    # records using bookmarkable details.
    #
    # First we want to group these by type into a hash to reduce queries:
    #
    # {
    #   "Post": {
    #     1234: <Post>,
    #     566: <Post>,
    #   },
    #   "Topic": {
    #     123: <Topic>,
    #     99: <Topic>,
    #   }
    # }
    #
    # We may not need to do this most of the time. It depends mostly on
    # a user's auto_delete_preference for bookmarks.
    deleted_bookmark_ids = reminder_bookmark_ids - bookmarks.map(&:id)
    deleted_bookmarkables =
      reminder_notifications
        .select do |notif|
          deleted_bookmark_ids.include?(notif.data_hash[:bookmark_id]) &&
            notif.data_hash[:bookmarkable_type].present?
        end
        .inject({}) do |hash, notif|
          hash[notif.data_hash[:bookmarkable_type]] ||= {}
          hash[notif.data_hash[:bookmarkable_type]][notif.data_hash[:bookmarkable_id]] = nil
          hash
        end

    # Then, we can actually find the associated records for each type in the database.
    deleted_bookmarkables.each do |type, bookmarkable|
      records = Bookmark.registered_bookmarkable_from_type(type).model.where(id: bookmarkable.keys)
      records.each { |record| deleted_bookmarkables[type][record.id] = record }
    end

    reminder_notifications.select do |notif|
      bookmark = bookmarks.find { |bm| bm.id == notif.data_hash[:bookmark_id] }

      # This is the happy path, it's easiest to look up using a bookmark
      # that hasn't been deleted.
      if bookmark.present?
        bookmarkable = Bookmark.registered_bookmarkable_from_type(bookmark.bookmarkable_type)
        bookmarkable.can_see?(@guardian, bookmark)
      else
        # Otherwise, we have to use our cached records from the deleted
        # bookmarks' related bookmarkable (e.g. Post, Topic) to determine
        # secure access.
        bookmarkable =
          deleted_bookmarkables.dig(
            notif.data_hash[:bookmarkable_type],
            notif.data_hash[:bookmarkable_id],
          )
        bookmarkable.present? &&
          Bookmark.registered_bookmarkable_from_type(
            notif.data_hash[:bookmarkable_type],
          ).can_see_bookmarkable?(@guardian, bookmarkable)
      end
    end
  end
end
