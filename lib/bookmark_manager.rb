# frozen_string_literal: true

class BookmarkManager
  include HasErrors

  def initialize(user)
    @user = user
  end

  # TODO (martin) (2021-12-01) Remove reminder_type keyword argument once plugins are not using it.
  def create(post_id:, name: nil, reminder_at: nil, reminder_type: nil, options: {})
    post = Post.find_by(id: post_id)

    # no bookmarking deleted posts or topics
    raise Discourse::InvalidAccess if post.blank? || post.topic.blank?

    if !Guardian.new(@user).can_see_post?(post) || !Guardian.new(@user).can_see_topic?(post.topic)
      raise Discourse::InvalidAccess
    end

    bookmark = Bookmark.create(
      {
        user_id: @user.id,
        post: post,
        name: name,
        reminder_at: reminder_at,
        reminder_set_at: Time.zone.now
      }.merge(options)
    )

    if bookmark.errors.any?
      return add_errors_from(bookmark)
    end

    update_topic_user_bookmarked(post.topic)

    bookmark
  end

  def destroy(bookmark_id)
    bookmark = find_bookmark_and_check_access(bookmark_id)

    bookmark.destroy

    bookmarks_remaining_in_topic = update_topic_user_bookmarked(bookmark.topic)

    { topic_bookmarked: bookmarks_remaining_in_topic }
  end

  def destroy_for_topic(topic, filter = {}, opts = {})
    topic_bookmarks = Bookmark.for_user_in_topic(@user.id, topic.id)
    topic_bookmarks = topic_bookmarks.where(filter)

    Bookmark.transaction do
      topic_bookmarks.each do |bookmark|
        raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_delete?(bookmark)
        bookmark.destroy
      end

      update_topic_user_bookmarked(topic, opts)
    end
  end

  def self.send_reminder_notification(id)
    bookmark = Bookmark.find_by(id: id)
    BookmarkReminderNotificationHandler.send_notification(bookmark)
  end

  # TODO (martin) (2021-12-01) Remove reminder_type keyword argument once plugins are not using it.
  def update(bookmark_id:, name:, reminder_at:, reminder_type: nil, options: {})
    bookmark = find_bookmark_and_check_access(bookmark_id)

    success = bookmark.update(
      {
        name: name,
        reminder_at: reminder_at,
        reminder_set_at: Time.zone.now
      }.merge(options)
    )

    if bookmark.errors.any?
      return add_errors_from(bookmark)
    end

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
    raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_edit?(bookmark)
    bookmark
  end

  def update_topic_user_bookmarked(topic, opts = {})
    # PostCreator can specify whether auto_track is enabled or not, don't want to
    # create a TopicUser in that case
    bookmarks_remaining_in_topic = Bookmark.for_user_in_topic(@user.id, topic.id).exists?
    return bookmarks_remaining_in_topic if opts.key?(:auto_track) && !opts[:auto_track]

    TopicUser.change(@user.id, topic, bookmarked: bookmarks_remaining_in_topic)
    bookmarks_remaining_in_topic
  end
end
