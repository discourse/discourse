# frozen_string_literal: true

class BasicReviewableQueuedPostSerializer < BasicReviewableSerializer
  attributes :topic_fancy_title, :payload_title, :is_new_topic

  def topic_fancy_title
    object.topic.fancy_title
  end

  def payload_title
    object.payload["title"]
  end

  def is_new_topic
    object.payload["title"].present?
  end

  def include_topic_fancy_title?
    object.topic.present?
  end

  def include_payload_title?
    is_new_topic
  end
end
