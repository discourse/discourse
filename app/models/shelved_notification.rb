# frozen_string_literal: true

class ShelvedNotification < ActiveRecord::Base
  self.ignored_columns = [
    :old_notification_id, # TODO: Remove once 20240829140226_drop_old_notification_id_columns has been promoted to pre-deploy
  ]

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
