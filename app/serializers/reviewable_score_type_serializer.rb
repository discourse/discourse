class ReviewableScoreTypeSerializer < ApplicationSerializer
  attributes :id, :title

  # Allow us to share post action type translations for backwards compatibility
  def title
    I18n.t("post_action_types.#{ReviewableScore.types[id]}.title", default: nil) ||
      I18n.t("reviewable_score_types.#{ReviewableScore.types[id]}.title")
  end

end
