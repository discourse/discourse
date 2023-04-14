# frozen_string_literal: true

class ShelvedNotification < ActiveRecord::Base
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
#  notification_id :integer          not null
#
# Indexes
#
#  index_shelved_notifications_on_notification_id  (notification_id)
#
