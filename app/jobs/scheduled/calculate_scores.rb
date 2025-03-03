# frozen_string_literal: true

module Jobs
  class CalculateScores < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      ScoreCalculator.new.calculate
    end
  end
end
