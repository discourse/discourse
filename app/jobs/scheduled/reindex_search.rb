module Jobs
  # if locale changes or search algorithm changes we may want to reindex stuff
  class ReindexSearch < Jobs::Scheduled
    every 1.day

    def execute(args)
      Search.rebuild_problem_posts
    end
  end
end
