# frozen_string_literal: true

require_dependency "reviewable_serializer"

class ReviewablePostVotingCommentSerializer < ReviewableSerializer
  target_attributes :cooked, :raw, :comment_cooked, :post_id
  payload_attributes :comment_cooked, :transcript_topic_id, :cooked, :raw, :created_by
  attributes :target_id, :comment_cooked, :target_created_at

  def created_from_flag?
    true
  end

  def target_id
    object.target&.id
  end

  def comment_cooked
    object.payload["comment_cooked"]
  end

  def target_created_at
    object.target&.created_at
  end

  def include_target_created_at?
    true
  end
end
