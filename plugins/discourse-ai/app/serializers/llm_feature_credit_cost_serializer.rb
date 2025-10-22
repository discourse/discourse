# frozen_string_literal: true

class LlmFeatureCreditCostSerializer < ApplicationSerializer
  attributes :id, :feature_name, :credits_per_token
end
