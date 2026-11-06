# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    # Suggests the DSA statement of reasons classification staff pick when moderating a
    # reviewable. Suggestions only pre-fill the form; staff still confirm them.
    module DsaClassification
      FEATURE_NAME = "dsa_classification"
      SUGGESTIONS_PER_MINUTE = 20

      Suggestion = Data.define(:community_rule, :category)
    end
  end
end
