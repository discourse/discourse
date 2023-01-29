# frozen_string_literal: true

# Deprecated, should be removed once users have sufficient opportunity to do so
class QueuedPostSerializer < ApplicationSerializer
  attributes(
    :id,
    :queue,
    :user_id,
    :state,
    :topic_id,
    :approved_by_id,
    :rejected_by_id,
    :raw,
    :post_options,
    :created_at,
    :category_id,
    :can_delete_user,
  )
  has_one :created_by, serializer: AdminUserListSerializer, root: :users
  has_one :topic, serializer: BasicTopicSerializer

  def queue
    "default"
  end

  def user_id
    object.created_by_id
  end

  def state
    object.status + 1
  end

  def approved_by_id
    post_history.approved.last&.created_by_id
  end

  def rejected_by_id
    post_history.rejected.last&.created_by_id
  end

  def raw
    object.payload["raw"]
  end

  def post_options
    object.payload.except("raw")
  end

  def can_delete_user
    true
  end

  def include_can_delete_user?
    created_by && created_by.trust_level == TrustLevel[0]
  end

  private

  def post_history
    object.reviewable_histories.transitioned.order(:created_at)
  end
end
