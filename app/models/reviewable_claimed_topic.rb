# frozen_string_literal: true

class ReviewableClaimedTopic < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user
  validates_uniqueness_of :topic

  def self.claimed_hash(topic_ids)
    result = {}
    if SiteSetting.reviewable_claiming != 'disabled'
      ReviewableClaimedTopic.where(topic_id: topic_ids).includes(:user).each do |rct|
        result[rct.topic_id] = rct.user
      end
    end
    result
  end
end

# == Schema Information
#
# Table name: reviewable_claimed_topics
#
#  id         :bigint           not null, primary key
#  user_id    :integer          not null
#  topic_id   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_reviewable_claimed_topics_on_topic_id  (topic_id) UNIQUE
#
