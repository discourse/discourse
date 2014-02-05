module Jobs

  class CategoryStats < Jobs::Scheduled
    every 4.hours

    def execute(args)
      Category.update_stats
    end

  end

end
