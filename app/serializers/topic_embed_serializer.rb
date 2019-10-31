# frozen_string_literal: true

class TopicEmbedSerializer < ApplicationSerializer
  attributes \
    :topic_id,
    :post_id,
    :topic_slug,
    :comment_count

  def topic_slug
    object.topic.slug
  end

  def comment_count
    object.topic.posts_count - 1
  end
end
