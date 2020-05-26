# frozen_string_literal: true

class BookmarkManager
  DEFAULT_OPTIONS = { delete_when_reminder_sent: false }

  include HasErrors

  def initialize(user)
    @user = user
  end

  def create(post_id:, name: nil, reminder_type: nil, reminder_at: nil, options: {})
    post = Post.unscoped.includes(:topic).find(post_id)
    reminder_type = parse_reminder_type(reminder_type)

    raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_see_post?(post)

    bookmark = Bookmark.create(
      {
        user_id: @user.id,
        topic: post.topic,
        post: post,
        name: name,
        reminder_type: reminder_type,
        reminder_at: reminder_at,
        reminder_set_at: Time.zone.now
      }.merge(default_options(options))
    )

    if bookmark.errors.any?
      return add_errors_from(bookmark)
    end

    update_topic_user_bookmarked(topic: post.topic, bookmarked: true)

    bookmark
  end

  def destroy(bookmark_id)
    bookmark = Bookmark.find_by(id: bookmark_id)

    raise Discourse::NotFound if bookmark.blank?
    raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_delete?(bookmark)

    bookmark.destroy

    bookmarks_remaining_in_topic = Bookmark.exists?(topic_id: bookmark.topic_id, user: @user)
    if !bookmarks_remaining_in_topic
      update_topic_user_bookmarked(topic: bookmark.topic, bookmarked: false)
    end

    { topic_bookmarked: bookmarks_remaining_in_topic }
  end

  def destroy_for_topic(topic)
    topic_bookmarks = Bookmark.where(user_id: @user.id, topic_id: topic.id)

    Bookmark.transaction do
      topic_bookmarks.each do |bookmark|
        raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_delete?(bookmark)
        bookmark.destroy
      end

      update_topic_user_bookmarked(topic: topic, bookmarked: false)
    end
  end

  def self.send_reminder_notification(id)
    bookmark = Bookmark.find_by(id: id)
    BookmarkReminderNotificationHandler.send_notification(bookmark)
  end

  def update(bookmark_id:, name:, reminder_type:, reminder_at:, options: {})
    bookmark = Bookmark.find_by(id: bookmark_id)

    raise Discourse::NotFound if bookmark.blank?
    raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_edit?(bookmark)

    reminder_type = parse_reminder_type(reminder_type)

    success = bookmark.update(
      {
        name: name,
        reminder_at: reminder_at,
        reminder_type: reminder_type,
        reminder_set_at: Time.zone.now
      }.merge(default_options(options))
    )

    if bookmark.errors.any?
      return add_errors_from(bookmark)
    end

    success
  end

  private

  def update_topic_user_bookmarked(topic:, bookmarked:)
    TopicUser.change(@user.id, topic, bookmarked: bookmarked)
  end

  def parse_reminder_type(reminder_type)
    return if reminder_type.blank?
    reminder_type.is_a?(Integer) ? reminder_type : Bookmark.reminder_types[reminder_type.to_sym]
  end

  def default_options(options)
    DEFAULT_OPTIONS.merge(options) { |key, old, new| new.nil? ? old : new }
  end
end
