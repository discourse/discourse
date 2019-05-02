# frozen_string_literal: true

class ReviewableSettingsSerializer < ApplicationSerializer
  attributes :id

  has_many :reviewable_score_types, serializer: ReviewableScoreTypeSerializer

  def id
    scope.user.id
  end

  def reviewable_score_types
    object[:reviewable_score_types]
  end
end
