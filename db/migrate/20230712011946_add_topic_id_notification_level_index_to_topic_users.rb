# frozen_string_literal: true
#
class AddTopicIdNotificationLevelIndexToTopicUsers < ActiveRecord::Migration[7.0]
  def change
    add_index :topic_users, %i[topic_id notification_level]
  end
end
