# frozen_string_literal: true

class TopicTrackingStateSerializer < ApplicationSerializer
  attributes :topic_id,
             :highest_post_number,
             :last_read_post_number,
             :created_at,
             :category_id,
             :notification_level,
             :created_in_new_period,
             :unread_not_too_old,
             :treat_as_new_topic_start_date

  def created_in_new_period
    return true if !scope
    object.created_at >= treat_as_new_topic_start_date
  end

  def unread_not_too_old
    return true if object.first_unread_at.blank?
    object.updated_at >= object.first_unread_at
  end
end
