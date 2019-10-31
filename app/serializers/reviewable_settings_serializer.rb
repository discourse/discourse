# frozen_string_literal: true

class ReviewableSettingsSerializer < ApplicationSerializer
  attributes :id, :reviewable_priorities

  has_many :reviewable_score_types, serializer: ReviewableScoreTypeSerializer

  def id
    scope.user.id
  end

  def reviewable_score_types
    object[:reviewable_score_types]
  end

  def reviewable_priorities
    Reviewable.priorities.map do |p|
      { id: p[1], name: I18n.t("reviewables.priorities.#{p[0]}") }
    end
  end
end
