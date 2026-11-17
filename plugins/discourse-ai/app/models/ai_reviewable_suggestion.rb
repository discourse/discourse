# frozen_string_literal: true

class AiReviewableSuggestion < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :decision_model
end
