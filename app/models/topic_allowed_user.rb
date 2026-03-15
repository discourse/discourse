# frozen_string_literal: true

class TopicAllowedUser < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user

  validates :topic_id, uniqueness: { scope: :user_id }

  after_commit :cleanup_inaccessible_notifications, on: :destroy

  private

  def cleanup_inaccessible_notifications
    Jobs.enqueue(:delete_inaccessible_notifications, topic_id: topic_id)
  end
end

# == Schema Information
#
# Table name: topic_allowed_users
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  topic_id   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_topic_allowed_users_on_topic_id_and_user_id  (topic_id,user_id) UNIQUE
#  index_topic_allowed_users_on_user_id_and_topic_id  (user_id,topic_id) UNIQUE
#
