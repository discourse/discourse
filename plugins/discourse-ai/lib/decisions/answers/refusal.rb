# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Answers
      Refusal =
        Data.define(:name) do
          def type = :refusal

          def refusal? = true

          %i[yes? no? probability choice score level probabilities confidence].each do |reader|
            define_method(reader) { |*| raise Refused.new(name) }
          end

          def to_h = { type: "refusal" }

          def as_json(*) = to_h.as_json
        end
    end
  end
end
