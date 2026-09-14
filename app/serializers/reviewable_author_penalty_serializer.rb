# frozen_string_literal: true

class ReviewableAuthorPenaltySerializer < ApplicationSerializer
  attributes :kind,
             :forever,
             :expires_at,
             :reason,
             :applied_at,
             :automatic,
             :from_this_target,
             :can_lift

  has_one :applied_by, serializer: BasicUserSerializer, embed: :objects

  def kind
    object.kind.to_s
  end

  def can_lift
    if object.kind == :suspension
      scope.can_unsuspend?(object.user)
    else
      scope.can_unsilence_user?(object.user)
    end
  end

  def include_expires_at?
    !object.forever
  end

  def include_reason?
    object.reason.present?
  end
end
