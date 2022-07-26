# frozen_string_literal: true

class BasicReviewableFlaggedPostSerializer < BasicReviewableSerializer
  attributes :post_number, :topic_fancy_title

  def post_number
    object.post.post_number
  end

  def topic_fancy_title
    object.topic.fancy_title
  end

  def include_post_number?
    object.post.present?
  end

  def include_topic_fancy_title?
    object.topic.present?
  end
end
