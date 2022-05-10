# frozen_string_literal: true

class BookmarkManager
  include HasErrors

  def initialize(user)
    @user = user
    @guardian = Guardian.new(user)
  end

  def self.bookmark_metadata(bookmark, user)
    if SiteSetting.use_polymorphic_bookmarks
      bookmark.registered_bookmarkable.bookmark_metadata(bookmark, user)
    else
      { topic_bookmarked: Bookmark.for_user_in_topic(user.id, bookmark.topic.id).exists? }
    end
  end

  # TODO (martin) [POLYBOOK] This will be used in place of #create once
  # polymorphic bookmarks are implemented.
  def create_for(bookmarkable_id:, bookmarkable_type:, name: nil, reminder_at: nil, options: {})
    raise NotImplementedError if !SiteSetting.use_polymorphic_bookmarks

    bookmarkable = bookmarkable_type.constantize.find_by(id: bookmarkable_id)
    registered_bookmarkable = Bookmark.registered_bookmarkable_from_type(bookmarkable_type)
    registered_bookmarkable.validate_before_create(@guardian, bookmarkable)

    bookmark = Bookmark.create(
      {
        user_id: @user.id,
        bookmarkable: bookmarkable,
        name: name,
        reminder_at: reminder_at,
        reminder_set_at: Time.zone.now
      }.merge(options)
    )

    return add_errors_from(bookmark) if bookmark.errors.any?

    registered_bookmarkable.after_create(@guardian, bookmark, options)
    update_user_option(bookmark)

    bookmark
  end

  ##
  # Creates a bookmark for a post where both the post and the topic are
  # not deleted. Only allows creation of bookmarks for posts the user
  # can access via Guardian.
  #
  # Any ActiveModel validation errors raised by the Bookmark model are
  # hoisted to the instance of this class for further reporting.
  #
  # Also handles setting the associated TopicUser.bookmarked value for
  # the post's topic for the user that is creating the bookmark.
  #
  # @param post_id       A post ID for a post that is not deleted.
  # @param name          A short note for the bookmark, shown on the user bookmark list
  #                      and on hover of reminder notifications.
  # @param reminder_at   The datetime when a bookmark reminder should be sent after.
  #                      Note this is not the exact time a reminder will be sent, as
  #                      we send reminders on a rolling schedule.
  #                      See Jobs::BookmarkReminderNotifications
  # @param for_topic     Whether we are creating a topic-level bookmark which
  #                      has different behaviour in the UI. Only bookmarks for
  #                      posts with post_number 1 can be marked as for_topic.
  # @params options      Additional options when creating a bookmark
  #                      - auto_delete_preference:
  #                        See Bookmark.auto_delete_preferences,
  #                        this is used to determine when to delete a bookmark
  #                        automatically.
  def create(
    post_id:,
    name: nil,
    reminder_at: nil,
    for_topic: false,
    options: {}
  )
    post = Post.find_by(id: post_id)
    if post.blank? ||
        post.topic.blank? ||
        !@guardian.can_see_topic?(post.topic) ||
        !@guardian.can_see_post?(post)
      raise Discourse::InvalidAccess
    end

    bookmark = Bookmark.create(
      {
        user_id: @user.id,
        post: post,
        name: name,
        reminder_at: reminder_at,
        reminder_set_at: Time.zone.now,
        for_topic: for_topic
      }.merge(options)
    )

    if bookmark.errors.any?
      return add_errors_from(bookmark)
    end

    update_topic_user_bookmarked(post.topic)
    update_user_option(bookmark)

    bookmark
  end

  def destroy(bookmark_id)
    bookmark = find_bookmark_and_check_access(bookmark_id)

    bookmark.destroy

    if SiteSetting.use_polymorphic_bookmarks
      bookmark.registered_bookmarkable.after_destroy(@guardian, bookmark)
    else
      update_topic_user_bookmarked(bookmark.topic)
    end

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
    bookmark = Bookmark.find_by(id: id)
    BookmarkReminderNotificationHandler.new(bookmark).send_notification
  end

  def update(bookmark_id:, name:, reminder_at:, options: {})
    bookmark = find_bookmark_and_check_access(bookmark_id)

    if bookmark.reminder_at != reminder_at
      bookmark.reminder_at = reminder_at
      bookmark.reminder_last_sent_at = nil
    end

    success = bookmark.update(
      {
        name: name,
        reminder_set_at: Time.zone.now,
      }.merge(options)
    )

    if bookmark.errors.any?
      return add_errors_from(bookmark)
    end

    update_user_option(bookmark)

    success
  end

  def toggle_pin(bookmark_id:)
    bookmark = find_bookmark_and_check_access(bookmark_id)
    bookmark.pinned = !bookmark.pinned
    success = bookmark.save

    if bookmark.errors.any?
      return add_errors_from(bookmark)
    end

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
    TopicUser.change(@user.id, topic, bookmarked: Bookmark.for_user_in_topic(@user.id, topic.id).exists?)
  end

  def update_user_option(bookmark)
    @user.user_option.update!(bookmark_auto_delete_preference: bookmark.auto_delete_preference)
  end
end
