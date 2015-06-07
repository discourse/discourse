require_dependency 'score_calculator'

module Jobs

  # This job will run on a regular basis to update statistics and denormalized data.
  # If it does not run, the site will not function properly.
  class Weekly < Jobs::Scheduled
    every 1.week

    def execute(args)
      Post.calculate_avg_time
      Topic.calculate_avg_time
      ScoreCalculator.new.calculate
      Draft.cleanup!
    end
  end
end
