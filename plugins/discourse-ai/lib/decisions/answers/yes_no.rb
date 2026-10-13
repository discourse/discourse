# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Answers
      YesNo =
        Data.define(:name, :probability) do
          def type = :yes_no

          def refusal? = false

          def yes?(threshold: 0.5) = probability >= threshold

          def no?(threshold: 0.5) = !yes?(threshold:)

          def to_h = { type: "yes_no", probability:, yes: yes? }

          def as_json(*) = to_h.as_json
        end
    end
  end
end
