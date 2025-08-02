# frozen_string_literal: true

class BookmarkManager
  include HasErrors

  def initialize(user)
    @user = user
    @guardian = Guardian.new(user)
  end

  def self.bookmark_metadata(bookmark, user)
    bookmark.registered_bookmarkable.bookmark_metadata(bookmark, user)
  end

  ##
  # Creates a bookmark for a registered bookmarkable (see Bookmark.register_bookmarkable
  # and RegisteredBookmarkable for details on this).
  #
  # Only allows creation of bookmarks for records the user
  # can access via Guardian.
  #
  # Any ActiveModel validation errors raised by the Bookmark model are
  # hoisted to the instance of this class for further reporting.
  #
  # Before creation validations, after create callbacks, and after delete
  # callbacks are all RegisteredBookmarkable specific and should be defined
  # there.
  #
  # @param [Integer] bookmarkable_id   The ID of the ActiveRecord model to attach the bookmark to.
  # @param [String]  bookmarkable_type The class name of the ActiveRecord model to attach the bookmark to.
  # @param [String]  name              A short note for the bookmark, shown on the user bookmark list
  #                                    and on hover of reminder notifications.
  # @param reminder_at                 The datetime when a bookmark reminder should be sent after.
  #                                    Note this is not the exact time a reminder will be sent, as
  #                                    we send reminders on a rolling schedule.
  #                                    See Jobs::BookmarkReminderNotifications
  # @params options                    Additional options when creating a bookmark
  #                                    - auto_delete_preference:
  #                                      See Bookmark.auto_delete_preferences,
  #                                      this is used to determine when to delete a bookmark
  #                                      automatically.
  def create_for(bookmarkable_id:, bookmarkable_type:, name: nil, reminder_at: nil, options: {})
    registered_bookmarkable = Bookmark.registered_bookmarkable_from_type(bookmarkable_type)

    if registered_bookmarkable.blank?
      return add_error(I18n.t("bookmarks.errors.invalid_bookmarkable", type: bookmarkable_type))
    end

    bookmarkable = registered_bookmarkable.model.find_by(id: bookmarkable_id)
    registered_bookmarkable.validate_before_create(@guardian, bookmarkable)

    bookmark =
      Bookmark.create(
        {
          user_id: @user.id,
          bookmarkable: bookmarkable,
          name: name,
          reminder_at: reminder_at,
          reminder_set_at: Time.zone.now,
        }.merge(bookmark_model_options_with_defaults(options)),
      )

    return add_errors_from(bookmark) if bookmark.errors.any?

    registered_bookmarkable.after_create(@guardian, bookmark, options)

    bookmark
  end

  def destroy(bookmark_id)
    bookmark = find_bookmark_and_check_access(bookmark_id)

    bookmark.destroy

    bookmark.registered_bookmarkable.after_destroy(@guardian, bookmark)

    bookmark
  end

  def destroy_for_topic(topic, filter = {}, opts = {})
    topic_bookmarks = Bookmark.for_user_in_topic(@user.id, topic.id)
    topic_bookmarks = topic_bookmarks.where(filter)

    Bookmark.transaction do
      topic_bookmarks.each do |bookmark|
        raise Discourse::InvalidAccess.new if !@guardian.can_delete?(bookmark)
        bookmark.destroy
      end

      update_topic_user_bookmarked(topic, opts)
    end
  end

  def self.send_reminder_notification(id)
    BookmarkReminderNotificationHandler.new(Bookmark.find_by(id: id)).send_notification
  end

  def update(bookmark_id:, name:, reminder_at:, options: {})
    bookmark = find_bookmark_and_check_access(bookmark_id)

    if bookmark.reminder_at != reminder_at
      bookmark.reminder_at = reminder_at
      bookmark.reminder_last_sent_at = nil
    end

    success =
      bookmark.update(
        { name: name, reminder_set_at: Time.zone.now }.merge(
          bookmark_model_options_with_defaults(options),
        ),
      )

    return add_errors_from(bookmark) if bookmark.errors.any?

    success
  end

  def toggle_pin(bookmark_id:)
    bookmark = find_bookmark_and_check_access(bookmark_id)
    bookmark.pinned = !bookmark.pinned
    success = bookmark.save

    return add_errors_from(bookmark) if bookmark.errors.any?

    success
  end

  private

  def find_bookmark_and_check_access(bookmark_id)
    bookmark = Bookmark.find_by(id: bookmark_id)
    raise Discourse::NotFound if !bookmark
    raise Discourse::InvalidAccess.new if !@guardian.can_edit?(bookmark)
    bookmark
  end

  def update_topic_user_bookmarked(topic, opts = {})
    # PostCreator can specify whether auto_track is enabled or not, don't want to
    # create a TopicUser in that case
    return if opts.key?(:auto_track) && !opts[:auto_track]
    TopicUser.change(
      @user.id,
      topic,
      bookmarked: Bookmark.for_user_in_topic(@user.id, topic.id).exists?,
    )
  end

  def bookmark_model_options_with_defaults(options)
    model_options = { pinned: options[:pinned] }

    if options[:auto_delete_preference].blank?
      model_options[:auto_delete_preference] = if user_auto_delete_preference.present?
        user_auto_delete_preference
      else
        Bookmark.auto_delete_preferences[:clear_reminder]
      end
    else
      model_options[:auto_delete_preference] = options[:auto_delete_preference]
    end

    model_options
  end

  def user_auto_delete_preference
    @guardian.user.user_option&.bookmark_auto_delete_preference
  end
end
