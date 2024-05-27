# frozen_string_literal: true

##
# Anything that we want to be able to bookmark must be registered as a
# bookmarkable type using Plugin::Instance#register_bookmarkable(bookmarkable_klass),
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
  #
  # Implementations can define their own preloading logic here
  # @param [Array] bookmarks_of_type The list of bookmarks to preload data for. Already filtered to be of the correct class.
  # @param [Guardian] guardian An instance of Guardian for the current_user
  def self.perform_custom_preload!(bookmarks_of_type, guardian)
    nil
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
  # @return [Bookmark::ActiveRecord_AssociationRelation] Should be an appropriately scoped list of bookmarks for the user.
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
  # Can be used by the inheriting class via reminder_handler, most of the
  # time we just want to make a Notification for a bookmark reminder, this
  # gives consumers a way to do it without having provide all of the required
  # data themselves.
  #
  # @param [Bookmark] bookmark          The bookmark that we are sending the reminder notification for.
  # @param [Hash]     notification_data Any data, either top-level (e.g. topic_id, post_number) or inside
  #                                     the data sub-key, which should be stored when the notification is
  #                                     created.
  # @return [void]
  def self.send_reminder_notification(bookmark, notification_data)
    if notification_data[:data].blank? || notification_data[:data][:bookmarkable_url].blank? ||
         notification_data[:data][:title].blank?
      raise Discourse::InvalidParameters.new(
              "A `data` key must be present with at least `bookmarkable_url` and `title` entries.",
            )
    end

    notification_data[:data] = notification_data[:data].merge(
      display_username: bookmark.user.username,
      bookmark_name: bookmark.name,
      bookmark_id: bookmark.id,
      bookmarkable_type: bookmark.bookmarkable_type,
      bookmarkable_id: bookmark.bookmarkable_id,
    ).to_json
    notification_data[:notification_type] = Notification.types[:bookmark_reminder]
    bookmark.user.notifications.create!(notification_data)
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
  # The can_see? method calls this one directly. can_see_bookmarkable? can be used
  # in cases where you know the bookmarkable based on type but don't have a bookmark
  # record to check against.
  #
  # @param [Guardian] guardian The guardian class for the user that we are performing the access check for.
  # @param [Bookmark] bookmarkable The bookmarkable which we are checking access for (e.g. Post, Topic) which is an ActiveModel instance.
  # @return [Boolean]
  def self.can_see_bookmarkable?(guardian, bookmarkable)
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

  ##
  # Some bookmarkable records are Trashable, and as such we don't delete the
  # bookmark with dependent_destroy. This should be used to delete those records
  # after a grace period, defined by the bookmarkable. For example, post bookmarks
  # may be deleted 3 days after the post or topic is deleted.
  #
  # In the case of bookmarkable records that are not trashable, and where
  # dependent_destroy is not used, this should just delete the bookmarks pointing
  # to the record which no longer exists in the database.
  def self.cleanup_deleted
    # noop
  end
end
