# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    module DsaClassification
      FEATURE_NAME = "dsa_classification"
      SUGGESTIONS_PER_MINUTE = 20

      Suggestion = Data.define(:community_rule, :category)
    end
  end
end
