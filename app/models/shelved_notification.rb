# frozen_string_literal: true

class ShelvedNotification < ActiveRecord::Base
  belongs_to :notification

  def process
    NotificationEmailer.process_notification(notification, no_delay: true)
  end
end
