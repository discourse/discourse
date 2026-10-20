# frozen_string_literal: true

class ReviewablePerformResultSerializer < ApplicationSerializer
  attributes(
    :success,
    :created_post_id,
    :created_post_topic_id,
    :remove_reviewable_ids,
    :reviewable_updates,
    :version,
    :reviewable_count,
    :unseen_reviewable_count,
    :edited_post,
  )

  def success
    object.success?
  end

  def reviewable_updates
    Reviewable
      .where(id: object.affected_reviewable_ids)
      .pluck(:id, :status)
      .to_h { |id, status| [id, { status: Reviewable.statuses[status] }] }
  end

  def include_reviewable_updates?
    object.affected_reviewable_ids.present?
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

  def edited_post
    PostSerializer.new(object.post_revision.post, scope:, root: false, add_raw: true).as_json
  end

  def include_edited_post?
    object.post_revision.present?
  end

  def reviewable_count
    scope.user.reviewable_count
  end

  def unseen_reviewable_count
    Reviewable.unseen_reviewable_count(scope.user)
  end
end
