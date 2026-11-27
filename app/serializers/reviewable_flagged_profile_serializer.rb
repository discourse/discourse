# frozen_string_literal: true

class ReviewableFlaggedProfileSerializer < ReviewableSerializer
  attributes :decision_score_ids
  payload_attributes :username,
                     :name,
                     :bio,
                     :location,
                     :website,
                     :avatar_url,
                     :title,
                     :profile_header_url,
                     :card_background_url,
                     :profile_fields

  def created_from_flag?
    true
  end

  def decision_score_ids
    object.scores_for_decision.map(&:id)
  end

  def target_url
    object.target_created_by&.relative_url
  end
end
