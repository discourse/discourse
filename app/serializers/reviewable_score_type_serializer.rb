# frozen_string_literal: true

class ReviewableScoreTypeSerializer < ApplicationSerializer
  attributes :id, :title, :reviewable_priority, :icon

  # Allow us to share post action type translations for backwards compatibility
  def title
    # Calling #try here because post action types don't have a reason method.
    I18n.t("reviewables.reason_titles.#{object.try(:reason)}", default: nil) ||
    I18n.t("post_action_types.#{ReviewableScore.types[id]}.title", default: nil) ||
      I18n.t("reviewable_score_types.#{ReviewableScore.types[id]}.title")
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
