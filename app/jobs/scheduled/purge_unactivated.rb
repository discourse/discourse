module Jobs
  class PurgeUnactived < Jobs::Scheduled
    every 1.day

    def execute(args)
      User.purge_unactivated
    end
  end
end
