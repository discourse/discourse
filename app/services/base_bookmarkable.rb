# frozen_string_literal: true

##
# Anything that we want to be able to bookmark must be registered as a
# bookmarkable type using Bookmark.register_bookmarkable(bookmarkable_klass),
# where the bookmarkable_klass is a class that implements this BaseBookmarkable
# interface. Some examples are TopicBookmarkable and PostBookmarkable.
#
# These methods are then called by the RegisteredBookmarkable class through a public
# interface, used in places where we need to list, send reminders for,
# or otherwise interact with bookmarks in a way that is unique to the
# bookmarkable type.
#
# See RegisteredBookmarkable for additional documentation.
class BaseBookmarkable
  attr_reader :model, :serializer, :preload_associations

  # @return [ActiveRecord::Base] The ActiveRecord model class which will be used to denote
  #                              the type of the bookmarkable upon registration along with
  #                              querying.
  def self.model
    raise NotImplementedError
  end

  # @return [ApplicationSerializer] The serializer class inheriting from UserBookmarkBaseSerializer
  def self.serializer
    raise NotImplementedError
  end

  # @return [Array] Used for preloading associations on the bookmarks for listing
  #                 purposes. Should be in the same format used for .includes() e.g.
  #
  #                 [{ topic: [:topic_users, :tags] }, :user]
  def self.preload_associations
    nil
  end

  def self.has_preloads?
    preload_associations.present?
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
  # @return [Bookmark::ActiveRecord_AssociationRelation] Should be an approprialely scoped list of bookmarks for the user.
  def self.list_query(user, guardian)
    raise NotImplementedError
  end

  ##
  # Called from BookmarkQuery when the initial results have been returned by
  # perform_list_query. The search_query should join additional tables required
  # to filter the bookmarks further, as well as defining a string used for
  # where_sql, which can include comparisons with the :q parameter.
  #
  # @param [Bookmark::ActiveRecord_Relation] bookmarks The bookmark records returned by perform_list_query
  # @param [String] query The search query from the user surrounded by the %% wildcards
  # @param [String] ts_query The postgres TSQUERY string used for comparisons with full text search columns
  # @param [Block] bookmarkable_search This block _must_ be called with the additional WHERE clause SQL relevant
  #                                    for the bookmarkable to be searched, as well as the bookmarks relation
  #                                    with any additional joins applied.
  # @return [Bookmark::ActiveRecord_AssociationRelation] The list of bookmarks from perform_list_query filtered further by
  #                                                      the query parameter.
  def self.search_query(bookmarks, query, ts_query, &bookmarkable_search)
    raise NotImplementedError
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
  # @return [Boolean]
  def self.reminder_conditions(bookmark)
    raise NotImplementedError
  end

  ##
  # Different bookmarkables may have different ways of notifying a user or presenting
  # the reminder and what it is for, so it is up to the bookmarkable to register
  # its preferred method of sending the reminder.
  #
  # @param [Bookmark] bookmark The bookmark that we are sending the reminder notification for.
  # @return [void]
  def self.reminder_handler(bookmark)
    raise NotImplementedError
  end

  ##
  # Access control is dependent on what has been bookmarked, the appropriate guardian
  # can_see_X? method should be called from the bookmarkable class to determine
  # whether the bookmarkable record (e.g. Post, Topic) is accessible by the guardian user.
  #
  # @param [Guardian] guardian The guardian class for the user that we are performing the access check for.
  # @param [Bookmark] bookmark The bookmark which we are checking access for using the bookmarkable association.
  # @return [Boolean]
  def self.can_see?(guardian, bookmark)
    raise NotImplementedError
  end

  ##
  # Some additional information about the bookmark or the surrounding relations
  # may be required when the bookmark is created or destroyed. For example, when
  # destroying a bookmark within a topic we need to know whether there are other
  # bookmarks still remaining in the topic.
  #
  # @param [Bookmark] bookmark The bookmark that we are retrieving additional metadata for.
  # @param [User] user The current user which is accessing the bookmark metadata.
  # @return [Hash] (optional)
  def self.bookmark_metadata(bookmark, user)
    {}
  end

  ##
  # Optional bookmarkable specific validations may need to be run before a bookmark is created
  # via the BookmarkManager. From here an error should be raised if there is an issue
  # with the bookmarkable.
  #
  # @param [Guardian] guardian The guardian for the user which is creating the bookmark.
  # @param [Model] bookmarkable The ActiveRecord model which is acting as the bookmarkable for the new bookmark.
  def self.validate_before_create(guardian, bookmarkable)
    # noop
  end

  ##
  # Optional additional actions may need to occur after a bookmark is created
  # via the BookmarkManager.
  #
  # @param [Guardian] guardian The guardian for the user which is creating the bookmark.
  # @param [Model] bookmark The bookmark which was created.
  # @param [Hash] opts Additional options that may be passed down via BookmarkManager.
  def self.after_create(guardian, bookmark, opts)
    # noop
  end

  ##
  # Optional additional actions may need to occur after a bookmark is destroyed
  # via the BookmarkManager.
  #
  # @param [Guardian] guardian The guardian for the user which is destroying the bookmark.
  # @param [Model] bookmark The bookmark which was destroyed.
  # @param [Hash] opts Additional options that may be passed down via BookmarkManager.
  def self.after_destroy(guardian, bookmark, opts)
    # noop
  end
end
