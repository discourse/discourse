# frozen_string_literal: true

class ReviewableClaimedTopic < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user
  validates :topic, uniqueness: true

  def self.release_manual_claim(topic_id, performed_by)
    find_by(topic_id:, automatic: false)&.release(performed_by)
  end

  def release(performed_by)
    delete
    log_topic_history(:unclaimed, performed_by) if SiteSetting.reviewable_claiming != "disabled"
    publish_change(performed_by, claimed: false)
  end

  def log_topic_history(type, performed_by)
    return if automatic?

    Reviewable
      .pending
      .where(topic_id:)
      .find_each { |reviewable| reviewable.log_history(type, performed_by) }
  end

  def publish_change(performed_by, claimed:)
    group_ids = [Group::AUTO_GROUPS[:staff]]

    if SiteSetting.enable_category_group_moderation?
      category = Topic.with_deleted.find_by(id: topic_id)&.category
      group_ids |= category.moderating_group_ids if category
    end

    data = {
      topic_id:,
      user: BasicUserSerializer.new(performed_by, root: false).as_json,
      automatic:,
      claimed:,
    }

    MessageBus.publish("/reviewable_claimed", data, group_ids:)

    Jobs.enqueue(:refresh_users_reviewable_counts, group_ids:)
  end

  def self.claimed_hash(topic_ids)
    result = {}
    if SiteSetting.reviewable_claiming == "disabled"
      ReviewableClaimedTopic
        .where(topic_id: topic_ids, automatic: true)
        .each { |rct| result[rct.topic_id] = rct }
    else
      ReviewableClaimedTopic.where(topic_id: topic_ids).each { |rct| result[rct.topic_id] = rct }
    end
    result
  end
end

# == Schema Information
#
# Table name: reviewable_claimed_topics
#
#  id         :bigint           not null, primary key
#  automatic  :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  topic_id   :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_reviewable_claimed_topics_on_topic_id  (topic_id) UNIQUE
#
