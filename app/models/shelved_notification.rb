# frozen_string_literal: true

class ShelvedNotification < ActiveRecord::Base
  # TODO(2025-01-15): Remove ignored_columns
  self.ignored_columns = [:old_notification_id]

  belongs_to :notification

  def process
    NotificationEmailer.process_notification(notification, no_delay: true)
  end
end

# == Schema Information
#
# Table name: shelved_notifications
#
#  id              :bigint           not null, primary key
#  notification_id :bigint           not null
#
# Indexes
#
#  index_shelved_notifications_on_notification_id  (notification_id)
#
