module Jobs

  class CalculateAvgTime < Jobs::Base

    def execute(args)
      Post.calculate_avg_time
      Topic.calculate_avg_time
    end

  end

end
