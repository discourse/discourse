# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Answers
      Refusal =
        Data.define(:name, :reason) do
          def initialize(name:, reason: nil)
            super(name:, reason:)
          end

          def refusal? = true

          def to_h
            { type: "refusal", reason: }
          end
        end
    end
  end
end
