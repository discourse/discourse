# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Answers
      Score =
        Data.define(:name, :score, :level, :probabilities, :confidence) do
          def initialize(**attributes)
            super(**attributes.merge(probabilities: attributes.fetch(:probabilities).dup.freeze))
          end

          def refusal? = false

          def to_h
            { type: "score", score:, level:, probabilities:, confidence: }
          end
        end
    end
  end
end
