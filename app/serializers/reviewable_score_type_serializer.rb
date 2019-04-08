class ReviewableScoreTypeSerializer < ApplicationSerializer
  attributes :id, :title, :score_bonus, :icon

  # Allow us to share post action type translations for backwards compatibility
  def title
    I18n.t("post_action_types.#{ReviewableScore.types[id]}.title", default: nil) ||
      I18n.t("reviewable_score_types.#{ReviewableScore.types[id]}.title")
  end

  def score_bonus
    object.score_bonus.to_f
  end

  def include_score_bonus?
    object.respond_to?(:score_bonus)
  end

  def icon
    "flag"
  end

end
