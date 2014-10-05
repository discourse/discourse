module Jobs
  class PurgeInactive < Jobs::Scheduled
    every 1.day

    def execute(args)
      User.purge_inactive
    end
  end
end

