class ReviewableClaimedTopic < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user

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
