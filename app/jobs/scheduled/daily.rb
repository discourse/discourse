require_dependency 'score_calculator'

module Jobs

  # This job will run on a regular basis to update statistics and denormalized data.
  # If it does not run, the site will not function properly.
  class Daily < Jobs::Scheduled
    every 1.day

    def execute(args)
      # TODO: optimise this against a big site before doing this any more
      # frequently
      #
      # current implementation wipes an entire table and rebuilds causing huge
      # amounts of IO
      TopTopic.refresh!
    end
  end
end
