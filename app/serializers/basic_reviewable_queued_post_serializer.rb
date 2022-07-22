# frozen_string_literal: true

class BasicReviewableQueuedPostSerializer < BasicReviewableSerializer
  attributes :topic_title, :is_new_topic

  def topic_title
    object.topic&.fancy_title || object.payload["title"]
  end

  def is_new_topic
    object.payload["title"].present?
  end
end
