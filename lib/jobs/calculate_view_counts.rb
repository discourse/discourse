require_dependency 'score_calculator'

module Jobs

  class CalculateViewCounts < Jobs::Base

    def execute(args)
      User.update_view_counts
    end

  end

end