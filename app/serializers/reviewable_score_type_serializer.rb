class ReviewableScoreTypeSerializer < ApplicationSerializer
  attributes :id, :title

  # For now these ids are the same as PostActionType
  def title
    I18n.t("post_action_types.#{PostActionType.types[id]}.title")
  end

end
