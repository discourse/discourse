module Jobs
  # various consistency checks
  class DestroyOldDeletionStubs < Jobs::Scheduled
    recurrence { hourly.minute_of_hour(0, 30) }

    def execute(args)
      PostDestroyer.destroy_stubs
    end
  end
end
