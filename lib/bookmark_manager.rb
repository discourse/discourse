# frozen_string_literal: true

class BookmarkManager
  include HasErrors

  def initialize(user)
    @user = user
  end

  def create(post_id:, name: nil, reminder_type: nil, reminder_at: nil)
    post = Post.unscoped.includes(:topic).find(post_id)
    reminder_type = Bookmark.reminder_types[reminder_type.to_sym] if reminder_type.present?

    raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_see_post?(post)

    bookmark = Bookmark.create(
      user_id: @user.id,
      topic: post.topic,
      post: post,
      name: name,
      reminder_type: reminder_type,
      reminder_at: reminder_at,
      reminder_set_at: Time.zone.now
    )

    if bookmark.errors.any?
      return add_errors_from(bookmark)
    end

    # bookmarking the topic-level mean
    if post.is_first_post?
      update_topic_user_bookmarked(topic: post.topic, bookmarked: true)
    end

    BookmarkReminderNotificationHandler.cache_pending_at_desktop_reminder(@user)
    bookmark
  end

  def destroy(bookmark_id)
    bookmark = Bookmark.find_by(id: bookmark_id)

    raise Discourse::NotFound if bookmark.blank?
    raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_delete?(bookmark)

    bookmark.destroy
    clear_at_desktop_cache_if_required
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

    clear_at_desktop_cache_if_required
  end

  def self.send_reminder_notification(id)
    bookmark = Bookmark.find_by(id: id)
    BookmarkReminderNotificationHandler.send_notification(bookmark)
  end

  private

  def clear_at_desktop_cache_if_required
    return if user_has_any_pending_at_desktop_reminders?
    Discourse.redis.del(BookmarkReminderNotificationHandler::PENDING_AT_DESKTOP_KEY_PREFIX + @user.id.to_s)
  end

  def user_has_any_pending_at_desktop_reminders?
    Bookmark.at_desktop_reminders_for_user(@user).any?
  end

  def update_topic_user_bookmarked(topic:, bookmarked:)
    TopicUser.change(@user.id, topic, bookmarked: bookmarked)
  end
end
