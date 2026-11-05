# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    module DsaClassification
      class Classifier
        def initialize(decision_model, questions: Questions.new)
          @decision_model = decision_model
          @questions = questions
        end

        # @return [Suggestion]
        # @raise [DiscourseAi::Decisions::Error]
        def suggest(reviewable, user:)
          result =
            @decision_model.decide(
              State.new(reviewable).to_s,
              questions: @questions.to_a,
              feature_name: FEATURE_NAME,
              user:,
            )
          @questions.suggestion_from(result)
        end
      end
    end
  end
end
