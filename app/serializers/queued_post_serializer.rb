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
    :can_delete_user
  )
  has_one :created_by, serializer: AdminUserListSerializer, root: :users
  has_one :topic, serializer: BasicTopicSerializer

  def queue
    'default'
  end

  def user_id
    object.created_by_id
  end

  def state
    object.status + 1
  end

  def approved_by_id
    who_did(:approved)
  end

  def rejected_by_id
    who_did(:rejected)
  end

  def raw
    object.payload['raw']
  end

  def post_options
    object.payload.except('raw')
  end

  def can_delete_user
    true
  end

  def include_can_delete_user?
    created_by && created_by.trust_level == TrustLevel[0]
  end

protected

  def who_did(status)
    object.
      reviewable_histories.
      where(
        reviewable_history_type: ReviewableHistory.types[:transitioned],
        status: Reviewable.statuses[status]
      ).
      order(:created_at)
      .last&.created_by_id
  end

end
