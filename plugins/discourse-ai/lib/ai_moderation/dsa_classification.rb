# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    module DsaClassification
      FEATURE_NAME = "dsa_classification"

      Suggestion = Data.define(:community_rule, :category)
    end
  end
end
