# frozen_string_literal: true

module DiscourseAi
  module Decisions
    def self.with_canned_answers(**answers)
      raise ArgumentError, "Canned answers cannot be nested" if CannedAnswers.current

      canned = CannedAnswers.new(answers)
      begin
        CannedAnswers.current = canned
        yield canned
      ensure
        CannedAnswers.current = nil
      end
    end
  end
end
