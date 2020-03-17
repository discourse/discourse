# frozen_string_literal: true

class BookmarkReminderNotificationHandler
  PENDING_AT_DESKTOP_KEY_PREFIX ||= 'pending_at_desktop_bookmark_reminder_user_'.freeze
  PENDING_AT_DESKTOP_EXPIRY_DAYS ||= 20

  def self.send_notification(bookmark)
    return if bookmark.blank?
    Bookmark.transaction do
      if bookmark.post.blank? || bookmark.post.deleted_at.present?
        return clear_reminder(bookmark)
      end

      create_notification(bookmark)
      clear_reminder(bookmark)
    end
  end

  def self.clear_reminder(bookmark)
    Rails.logger.debug(
      "Clearing bookmark reminder for bookmark_id #{bookmark.id}. reminder info: #{bookmark.reminder_at} | #{Bookmark.reminder_types[bookmark.reminder_type]}"
    )

    bookmark.update(
      reminder_at: nil,
      reminder_type: nil,
      reminder_last_sent_at: Time.zone.now,
      reminder_set_at: nil
    )
  end

  def self.create_notification(bookmark)
    user = bookmark.user
    user.notifications.create!(
      notification_type: Notification.types[:bookmark_reminder],
      topic_id: bookmark.topic_id,
      post_number: bookmark.post.post_number,
      data: {
        topic_title: bookmark.topic.title,
        display_username: user.username,
        bookmark_name: bookmark.name
      }.to_json
    )
  end

  def self.user_has_pending_at_desktop_reminders?(user)
    Discourse.redis.exists("#{PENDING_AT_DESKTOP_KEY_PREFIX}#{user.id}")
  end

  def self.cache_pending_at_desktop_reminder(user)
    Discourse.redis.setex("#{PENDING_AT_DESKTOP_KEY_PREFIX}#{user.id}", PENDING_AT_DESKTOP_EXPIRY_DAYS.days, true)
  end

  def self.send_at_desktop_reminder(user:, request_user_agent:)
    return if !SiteSetting.enable_bookmarks_with_reminders

    return if MobileDetection.mobile_device?(request_user_agent)

    return if !user_has_pending_at_desktop_reminders?(user)

    DistributedMutex.synchronize("sending_at_desktop_bookmark_reminders_user_#{user.id}") do
      Bookmark.at_desktop_reminders_for_user(user).each do |bookmark|
        BookmarkReminderNotificationHandler.send_notification(bookmark)
      end
      Discourse.redis.del("#{PENDING_AT_DESKTOP_KEY_PREFIX}#{user.id}")
    end
  end

  def self.defer_at_desktop_reminder(user:, request_user_agent:)
    Scheduler::Defer.later "Sending Desktop Bookmark Reminders" do
      send_at_desktop_reminder(user: user, request_user_agent: request_user_agent)
    end
  end
end
