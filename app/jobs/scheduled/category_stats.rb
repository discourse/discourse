module Jobs

  class CategoryStats < Jobs::Scheduled
    recurrence { daily.hour_of_day(4) }

    def execute(args)
      Category.update_stats
    end

  end

end