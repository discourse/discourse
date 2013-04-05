module Jobs
  # checks to see if any users need to be promoted
  class EnsureDbConsistency < Jobs::Base
    def execute(args)
      TopicUser.ensure_consistency!
      UserVisit.ensure_consistency!
    end
  end
end
