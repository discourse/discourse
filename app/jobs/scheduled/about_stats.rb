module Jobs
  class AboutStats < Jobs::Scheduled
    include Jobs::Stats

    every 30.minutes

    def execute(args)
      stats = About.new.stats
      set_cache(About, stats)
      stats
    end
  end
end
