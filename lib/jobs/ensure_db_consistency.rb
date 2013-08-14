module Jobs
  # various consistency checks
  class EnsureDbConsistency < Jobs::Scheduled
    recurrence { daily.hour_of_day(2) }

    def execute(args)
      TopicUser.ensure_consistency!
      UserVisit.ensure_consistency!
      Group.refresh_automatic_groups!
      Notification.ensure_consistency!
      UserAction.ensure_consistency!
    end
  end
end
