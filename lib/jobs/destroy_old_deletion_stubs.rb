module Jobs
  # various consistency checks
  class DestroyOldDeletionStubs < Jobs::Base
    def execute(args)
      PostDestroyer.destroy_stubs
    end
  end
end
