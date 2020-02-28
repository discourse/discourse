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
      reminder_at: reminder_at
    )

    if bookmark.errors.any?
      add_errors_from(bookmark)
      return
    end

    if needs_reminder?(bookmark)
      Jobs.enqueue_at(reminder_at, :bookmark_reminder, bookmark_id: bookmark.id)
    end

    bookmark
  end

  def destroy(id)
    bookmark = Bookmark.find_by(id: id)

    raise Discourse::NotFound if bookmark.blank?
    raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_delete?(bookmark)

    cancel_reminder(bookmark) if reminder_scheduled?(bookmark.id)

    bookmark.destroy
  end

  def destroy_for_topic(topic)
    topic_bookmarks = Bookmark.where(user_id: @user.id, topic_id: topic.id)

    Bookmark.transaction do
      topic_bookmarks.each do |bookmark|
        raise Discourse::InvalidAccess.new if !Guardian.new(@user).can_delete?(bookmark)
        bookmark.destroy

        cancel_reminder(bookmark) if reminder_scheduled?(bookmark.id)
      end
    end
  end

  def reminder_scheduled?(id)
    Jobs.scheduled_for(:bookmark_reminder, bookmark_id: id).any?
  end

  private

  def topic_id_for_post(post_id)
    Post.select(:topic_id).find(post_id).topic_id
  end

  def needs_reminder?(bookmark)
    bookmark.reminder_at.present? && bookmark.reminder_type != Bookmark.reminder_types[:at_desktop]
  end

  def cancel_reminder(bookmark)
    Jobs.cancel_scheduled_job(:bookmark_reminder, bookmark_id: bookmark.id)
  end
end
