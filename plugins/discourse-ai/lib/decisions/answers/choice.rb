# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Answers
      Choice =
        Data.define(:name, :choice, :probabilities, :confidence) do
          def initialize(**attributes)
            super(**attributes.merge(probabilities: attributes.fetch(:probabilities).dup.freeze))
          end

          def refusal? = false

          def to_h
            { type: "choice", choice:, probabilities:, confidence: }
          end
        end
    end
  end
end
