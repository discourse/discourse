module Jobs

  class CategoryStats < Jobs::Base

    def execute(args)
      Category.update_stats
    end

  end

end