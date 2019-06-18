# frozen_string_literal: true

class ReviewablePerformResultSerializer < ApplicationSerializer

  attributes(
    :success,
    :transition_to,
    :transition_to_id,
    :created_post_id,
    :created_post_topic_id,
    :remove_reviewable_ids,
    :version,
    :reviewable_count
  )

  def success
    object.success?
  end

  def transition_to_id
    Reviewable.statuses[transition_to]
  end

  def version
    object.reviewable.version
  end

  def created_post_id
    object.created_post.id
  end

  def include_created_post_id?
    object.created_post.present?
  end

  def created_post_topic_id
    object.created_post_topic.id
  end

  def include_created_post_topic_id?
    object.created_post_topic.present?
  end

  def reviewable_count
    Reviewable.list_for(scope.user).count
  end
end
