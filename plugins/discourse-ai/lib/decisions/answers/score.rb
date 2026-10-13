# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Answers
      # `score` is the probability-weighted level index, so it can fall between levels.
      # `level` is the label of the most likely level. `probabilities` maps each level
      # label to its probability, lowest level first.
      Score =
        Data.define(:name, :score, :level, :probabilities, :confidence) do
          def type = :score

          def refusal? = false

          def to_h = { type: "score", score:, level:, probabilities:, confidence: }

          def as_json(*) = to_h.as_json
        end
    end
  end
end
