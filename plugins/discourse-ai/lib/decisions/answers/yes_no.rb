# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Answers
      YesNo =
        Data.define(:name, :probability) do
          def refusal? = false

          def to_h
            { type: "yes_no", probability: }
          end
        end
    end
  end
end
