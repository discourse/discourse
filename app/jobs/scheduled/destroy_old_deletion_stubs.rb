module Jobs
  # various consistency checks
  class DestroyOldDeletionStubs < Jobs::Scheduled
    every 30.minutes

    def execute(args)
      PostDestroyer.destroy_stubs
    end
  end
end
