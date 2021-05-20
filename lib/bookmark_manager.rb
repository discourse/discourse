# frozen_string_literal: true

class BookmarkManager
  include HasErrors

  def initialize(user)
    @user = user
  end

  def create(post_id:, name: nil, reminder_type: nil, reminder_at: nil, options: {})
    post = Post.find_by(id: post_id)
    reminder_type = parse_reminder_type(reminder_type)

    # no bookmarking deleted posts or topics
    raise Discourse::InvalidAccess if post.blank? || post.topic.blank?

    if !Guardian.new(@user).can_see_post?(post) || !Guardian.new(@user).can_see_topic?(post.topic)
      raise Discourse::InvalidAccess
    end

    bookmark = Bookmark.create(
      {
        user_id: @user.id,
        topic: post.topic,
        post: post,
        name: name,
        reminder_type: reminder_type,
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
    topic_bookmarks = Bookmark.where(user_id: @user.id, topic_id: topic.id)
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

  def update(bookmark_id:, name:, reminder_type:, reminder_at:, options: {})
    bookmark = find_bookmark_and_check_access(bookmark_id)

    reminder_type = parse_reminder_type(reminder_type)

    success = bookmark.update(
      {
        name: name,
        reminder_at: reminder_at,
        reminder_type: reminder_type,
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
    bookmarks_remaining_in_topic = Bookmark.exists?(topic_id: topic.id, user: @user)
    return bookmarks_remaining_in_topic if opts.key?(:auto_track) && !opts[:auto_track]

    TopicUser.change(@user.id, topic, bookmarked: bookmarks_remaining_in_topic)
    bookmarks_remaining_in_topic
  end

  def parse_reminder_type(reminder_type)
    return if reminder_type.blank?
    reminder_type.is_a?(Integer) ? reminder_type : Bookmark.reminder_types[reminder_type.to_sym]
  end
end
