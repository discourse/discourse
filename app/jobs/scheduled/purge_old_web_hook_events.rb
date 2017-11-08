module Jobs
  class PurgeOldWebHookEvents < Jobs::Scheduled
    every 1.week

    def execute(_)
      WebHookEvent.purge_old
    end
  end
end
