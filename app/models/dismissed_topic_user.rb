# frozen_string_literal: true

class DismissedTopicUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic

  def self.lookup_for(user, topics)
    return [] if user.blank? || topics.blank?

    topic_ids = topics.map(&:id)
    DismissedTopicUser.where(topic_id: topic_ids, user_id: user.id).pluck(:topic_id)
  end
end

# == Schema Information
#
# Table name: dismissed_topic_users
#
#  id         :bigint           not null, primary key
#  user_id    :integer
#  topic_id   :integer
#  created_at :datetime
#
# Indexes
#
#  index_dismissed_topic_users_on_user_id_and_topic_id  (user_id,topic_id) UNIQUE
#
