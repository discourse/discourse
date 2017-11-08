module Jobs
  class PurgeOldWebHookEvents < Jobs::Scheduled
    every 1.day

    def execute(_)
      WebHookEvent.purge_old
    end
  end
end
