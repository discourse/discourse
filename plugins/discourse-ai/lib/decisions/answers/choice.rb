# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Answers
      # `probabilities` maps every option value to its probability.
      Choice =
        Data.define(:name, :choice, :probabilities, :confidence) do
          def type = :choice

          def refusal? = false

          def to_h = { type: "choice", choice:, probabilities:, confidence: }

          def as_json(*) = to_h.as_json
        end
    end
  end
end
