# frozen_string_literal: true

class ReviewablePerformResultSerializer < ApplicationSerializer
  attributes(
    :success,
    :transition_to,
    :transition_to_id,
    :created_post_id,
    :created_post_topic_id,
    :update_reviewable_statuses,
    :version,
    :reviewable_count,
    :unseen_reviewable_count,
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

  def include_update_reviewable_statuses?
    object.update_reviewable_statuses.present?
  end

  def reviewable_count
    scope.user.reviewable_count
  end

  def unseen_reviewable_count
    Reviewable.unseen_reviewable_count(scope.user)
  end
end
