module Jobs
  # various consistency checks
  class EnsureDbConsistency < Jobs::Base
    def execute(args)
      TopicUser.ensure_consistency!
      UserVisit.ensure_consistency!
      Group.refresh_automatic_groups!
    end
  end
end
