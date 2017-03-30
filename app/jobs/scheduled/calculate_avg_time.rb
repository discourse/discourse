module Jobs
  class CalculateAvgTime < Jobs::Scheduled
    every 1.day

    # PERF: these calculations can become exceedingly expnsive
    #  they run a huge gemoetric mean and are hard to optimise
    #  defer to only run once a day
    def execute(args)
      # Update the average times
      Post.calculate_avg_time(2.days.ago)
      Topic.calculate_avg_time(2.days.ago)
    end
  end
end
