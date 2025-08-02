# frozen_string_literal: true

class ReviewableScoreTypeSerializer < ApplicationSerializer
  attributes :id, :title, :reviewable_priority, :icon, :type

  def type
    ReviewableScore.types[id]
  end

  # Allow us to share post action type translations for backwards compatibility
  def title
    ReviewableScore.type_title(type)
  end

  def reviewable_priority
    object.reviewable_priority.to_i
  end

  def include_reviewable_priority?
    object.respond_to?(:reviewable_priority)
  end

  def icon
    "flag"
  end
end
