# frozen_string_literal: true

class TopicAllowedGroup < ActiveRecord::Base
  belongs_to :topic
  belongs_to :group

  validates :topic_id, uniqueness: { scope: :group_id }

  after_commit :cleanup_inaccessible_notifications, on: :destroy

  private

  def cleanup_inaccessible_notifications
    Jobs.enqueue(:delete_inaccessible_notifications, topic_id: topic_id)
  end
end

# == Schema Information
#
# Table name: topic_allowed_groups
#
#  id       :integer          not null, primary key
#  group_id :integer          not null
#  topic_id :integer          not null
#
# Indexes
#
#  index_topic_allowed_groups_on_group_id_and_topic_id  (group_id,topic_id) UNIQUE
#  index_topic_allowed_groups_on_topic_id_and_group_id  (topic_id,group_id) UNIQUE
#
