# frozen_string_literal: true

class ReviewableScoreExplanationSerializer < ApplicationSerializer
  attributes(
    :user_id,
    :type_bonus,
    :trust_level_bonus,
    :take_action_bonus,
    :flags_agreed,
    :flags_disagreed,
    :flags_ignored,
    :user_accuracy_bonus,
    :score
  )

  def user_accuracy_bonus
    ReviewableScore.calc_user_accuracy_bonus(
      object.flags_agreed,
      object.flags_disagreed,
      object.flags_ignored
    )
  end

end
