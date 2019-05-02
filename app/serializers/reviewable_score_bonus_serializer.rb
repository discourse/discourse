# frozen_string_literal: true

class ReviewableScoreBonusSerializer < ApplicationSerializer
  attributes :id, :name, :score_bonus

  def name
    I18n.t("post_action_types.#{object.name_key}.title")
  end
end
