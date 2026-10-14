# frozen_string_literal: true

class AiDecisionModelSerializer < ApplicationSerializer
  root "ai_decision_model"

  attributes :id, :display_name, :name, :provider, :url, :ai_secret_id, :vision_enabled
end
