# frozen_string_literal: true

class TopicTrackingStateItemSerializer < ApplicationSerializer
  attributes :topic_id,
             :highest_post_number,
             :last_read_post_number,
             :created_at,
             :category_id,
             :is_category_topic,
             :notification_level,
             :created_in_new_period,
             :treat_as_new_topic_start_date,
             :tags

  def created_in_new_period
    return true if !scope
    object.created_at >= treat_as_new_topic_start_date
  end

  def include_tags?
    object.respond_to?(:tags)
  end

  def is_category_topic
    object.topic_id == object.category_topic_id
  end

  def include_is_category_topic?
    object.respond_to?(:category_topic_id)
  end
end
