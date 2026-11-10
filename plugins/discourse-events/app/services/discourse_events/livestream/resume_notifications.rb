# frozen_string_literal: true

class DiscourseEvents::Livestream::ResumeNotifications
  include Service::Base

  params do
    attribute :pause_key, :string

    validates :pause_key, presence: true, format: { with: /\A[0-9a-f-]{36}\z/ }
  end

  model :notification_pause, :build_notification_pause
  step :end_pause
  step :announce_remaining_pause
  only_if(:no_longer_paused) { step :deliver_shelved_notifications }

  private

  def build_notification_pause(params:, guardian:)
    DiscourseEvents::Livestream::NotificationPause.new(user: guardian.user, key: params.pause_key)
  end

  def end_pause(notification_pause:)
    notification_pause.end
  end

  def announce_remaining_pause(guardian:)
    guardian.user.publish_do_not_disturb(ends_at: guardian.user.do_not_disturb_until)
  end

  def no_longer_paused(guardian:)
    !guardian.user.do_not_disturb?
  end

  def deliver_shelved_notifications(guardian:)
    shelved_notifications = guardian.user.shelved_notifications
    shelved_notifications.each(&:process)
    shelved_notifications.destroy_all
  end
end
