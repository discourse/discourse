# frozen_string_literal: true

class BookmarkManager
  include HasErrors

  def initialize(user)
    @user = user
  end

  def create(post_id:, name: nil, reminder_type: nil, reminder_at: nil)
    reminder_type = Bookmark.reminder_types[reminder_type.to_sym] if reminder_type.present?

    bookmark = Bookmark.create(
      user_id: @user.id,
      topic_id: topic_id_for_post(post_id),
      post_id: post_id,
      name: name,
      reminder_type: reminder_type,
      reminder_at: reminder_at,
      reminder_set_at: Time.now.utc
    )

    if bookmark.errors.any?
      add_errors_from(bookmark)
      return
    end

    BookmarkReminderNotificationHandler.cache_pending_at_desktop_reminder(@user)
    bookmark
  end

  def destroy(bookmark_id)
    bookmark = Bookmark.find_by(id: bookmark_id)

    raise Discourse::NotFound if bookmark.blank?
    raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_delete?(bookmark)

    bookmark.destroy
  end

  def destroy_for_topic(topic)
    topic_bookmarks = Bookmark.where(user_id: @user.id, topic_id: topic.id)

    Bookmark.transaction do
      topic_bookmarks.each do |bookmark|
        raise Discourse::InvalidAccess.new if !Guardian.new(user).can_delete?(bookmark)
        bookmark.destroy
      end
    end
  end

  def self.send_reminder_notification(id)
    bookmark = Bookmark.find_by(id: id)
    BookmarkReminderNotificationHandler.send_notification(bookmark)
  end

  private

  def topic_id_for_post(post_id)
    Post.select(:topic_id).find(post_id).topic_id
  end
end
