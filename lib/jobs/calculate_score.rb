require_dependency 'score_calculator'

module Jobs

  class CalculateScore < Jobs::Base

    def execute(args)
      ScoreCalculator.new.calculate
    end

  end

end