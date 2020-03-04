# frozen_string_literal: true

class BookmarkReminderNotificationHandler
  def self.send_notification(bookmark)
    return if bookmark.blank?
    Bookmark.transaction do
      if bookmark.post.blank?
        Rails.logger.warn("The post for bookmark_id #{bookmark.id} has been deleted, clearing reminder.")
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
      reminder_last_sent_at: Time.now.utc
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

  def self.send_at_desktop_reminder(user:, request:)
    return if !SiteSetting.enable_bookmarks_with_reminders

    device = BrowserDetection.device(request.user_agent).to_s

    last_used_device_key = "last_used_device_user_#{user.id}"
    last_used_device = Discourse.redis.get(last_used_device_key)
    if last_used_device != device
      Discourse.redis.set(last_used_device_key, device)
    end

    # if we are still on the mobile no need to send any desktop notifications,
    # same if we have not moved anywhere
    mobile_device = BrowserDetection.mobile_device?(device)
    last_used_device_was_desktop = last_used_device.present? && BrowserDetection.desktop_device?(last_used_device)
    still_on_desktop = !mobile_device && last_used_device_was_desktop

    return if last_used_device == device || still_on_desktop || mobile_device

    DistributedMutex.synchronize("sending_at_desktop_bookmark_reminders_user_#{user.id}") do
      at_desktop_reminders = Bookmark.at_desktop_reminders_for_user(user)
      at_desktop_reminders.each do |bookmark|
        BookmarkReminderNotificationHandler.send_notification(bookmark)
      end
    end
  end
end
