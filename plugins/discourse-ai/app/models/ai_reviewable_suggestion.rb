# frozen_string_literal: true

class AiReviewableSuggestion < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :decision_model

  scope :actionable,
        ->(min_confidence: SiteSetting.ai_reviewable_action_min_confidence) do
          where.not(action_name: nil).where(
            "ai_reviewable_suggestions.confidence >= ?",
            min_confidence,
          )
        end

  def actionable?(min_confidence: SiteSetting.ai_reviewable_action_min_confidence)
    action_name.present? && confidence.present? && confidence >= min_confidence
  end
end

# == Schema Information
#
# Table name: ai_reviewable_suggestions
#
#  id                :bigint           not null, primary key
#  action_name       :string
#  confidence        :float
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  decision_model_id :bigint           not null
#  reviewable_id     :bigint           not null
#
# Indexes
#
#  index_ai_reviewable_suggestions_on_reviewable_id  (reviewable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (reviewable_id => reviewables.id) ON DELETE => cascade
#
