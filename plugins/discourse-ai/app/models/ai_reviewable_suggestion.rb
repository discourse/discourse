# frozen_string_literal: true

class AiReviewableSuggestion < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :decision_model
end

# == Schema Information
#
# Table name: ai_reviewable_suggestions
#
#  id                :bigint           not null, primary key
#  action_name       :string           not null
#  confidence        :float            not null
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
