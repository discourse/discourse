# frozen_string_literal: true

module DiscourseAi
  module Decisions
    # Answers every decision model call in the block with canned values instead
    # of hitting the network. Meant for specs.
    #
    #   DiscourseAi::Decisions.with_canned_answers(spam: 0.93, team: "billing") do |canned|
    #     # ... code that calls DecisionModel#decide ...
    #     expect(canned.calls.first[:state]).to include("payouts")
    #   end
    #
    # Pass an exception instead of answers to make every call raise it.
    def self.with_canned_answers(error = nil, **answers)
      raise "Canned answers can't be nested" if CannedAnswers.current

      canned = CannedAnswers.new(answers, error:)
      CannedAnswers.current = canned
      result = yield(canned)
      canned.verify_all_used!
      result
    ensure
      CannedAnswers.current = nil if CannedAnswers.current == canned
    end
  end
end
