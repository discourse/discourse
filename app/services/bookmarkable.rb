# frozen_string_literal: true
#
# Should only be created via the Bookmark.register_bookmarkable
# method; this is used to let the BookmarkQuery class query and
# search additional bookmarks for the user bookmark list, and
# also to enumerate on the registered Bookmarkable types.
#
# Post and Topic bookmarkables are registered by default.
#
# Anything other than types registered in this way will throw an error
# when trying to save the Bookmark record. All things that are bookmarkable
# must be registered in this way.
#
# See Bookmark#reset_bookmarkables for some examples on how registering
# bookmarkables works.
class Bookmarkable
  attr_reader :model, :serializer, :list_query, :search_query, :reminder_handler, :preload_associations, :reminder_conditions

  delegate :table_name, to: :@model

  def initialize(
    model:, serializer:, list_query:, search_query:, reminder_handler:, preload_associations: [], reminder_conditions: nil
  )
    @model = model
    @serializer = serializer
    @list_query = list_query
    @search_query = search_query
    @reminder_handler = reminder_handler
    @preload_associations = preload_associations
    @reminder_conditions = reminder_conditions
  end

  ##
  # This is where the main query to filter the bookmarks by the provided bookmarkable
  # type should occur. This should join on additional tables that are required later
  # on to preload additional data for serializers, and also is the place where the
  # bookmarks should be filtered based on security checks, which is why the Guardian
  # instance is provided.
  #
  # @param [User] user The user to perform the query for, this scopes the bookmarks returned.
  # @param [Guardian] guardian An instance of Guardian for the user to be used for security filters.
  def perform_list_query(user, guardian)
    list_query.call(user, guardian)
  end

  ##
  # Called from BookmarkQuery when the initial results have been returned by
  # perform_list_query. The search_query should join additional tables required
  # to filter the bookmarks further, as well as defining a string used for
  # where_sql, which can include comparisons with the :q parameter.
  #
  # The block here warrants explanation -- when the search_query is called, we
  # call the provided block with the bookmark relation with additional joins
  # as well as the where_sql string, and then also add the additional OR bookmarks.name
  # filter. This is so every bookmarkable is filtered by its own customized
  # columns _as well as_ the bookmark name, because the bookmark name must always
  # be used in the search.
  #
  # @param [Bookmark::ActiveRecord_Relation] bookmarks The bookmark records returned by perform_list_query
  # @param [String] query The search query from the user surrounded by the %% wildcards
  # @param [String] ts_query The postgres TSQUERY string used for comparisons with full text search columns
  def perform_search_query(bookmarks, query, ts_query)
    search_query.call(bookmarks, query, ts_query) do |bookmarks_joined, where_sql|
      bookmarks_joined.where("#{where_sql} OR bookmarks.name ILIKE :q", q: query)
    end
  end

  ##
  # When displaying the bookmarks in a list for a user there is often additional
  # information drawn from other tables joined to the bookmarkable that must
  # be displayed. We preload these additional associations here on top of the
  # array of bookmarks which has already been filtered, offset by page, ordered,
  # and limited. The preload_associations array should be in the same format as
  # used for .includes() e.g.
  #
  # [{ topic: [:topic_users, :tags] }, :user]
  #
  # @param [Array] bookmarks The array of bookmarks after initial listing and filtering, note this is
  #                          array _not_ an ActiveRecord::Relation.
  def perform_preload(bookmarks)
    ActiveRecord::Associations::Preloader
      .new(records: Bookmark.select_type(bookmarks, model.to_s), associations: [bookmarkable: preload_associations])
      .call
  end

  ##
  # When sending bookmark reminders, we want to make sure that whatever we
  # are sending the reminder for has not been deleted or is otherwise inaccessible.
  # Most of the time we can just check if the bookmarkable record is present
  # because it will be trashable, though in some cases there will be additional
  # conditions in the form of a lambda that we should use instead.
  #
  # The logic around whether it is the right time to send a reminder does not belong
  # here, that is done in the BookmarkReminderNotifications job.
  #
  # @param [Bookmark] bookmark The bookmark that we are considering sending a reminder for.
  def can_send_reminder?(bookmark)
    return reminder_conditions.call(bookmark) if reminder_conditions.present?
    bookmark.bookmarkable.present?
  end

  ##
  # Different bookmarkables may have different ways of notifying a user or presenting
  # the reminder and what it is for, so it is up to the bookmarkable to register
  # its preferred method of sending the reminder.
  #
  # @param [Bookmark] bookmark The bookmark that we are sending the reminder notification for.
  def send_reminder_notification(bookmark)
    reminder_handler.call(bookmark)
  end
end
