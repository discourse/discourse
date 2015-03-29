module Jobs
  # various consistency checks
  class EnsureDbConsistency < Jobs::Scheduled
    every 12.hours

    def execute(args)
      UserVisit.ensure_consistency!
      Group.refresh_automatic_groups!
      Notification.ensure_consistency!
      UserAction.ensure_consistency!
      TopicFeaturedUsers.ensure_consistency!
      PostRevision.ensure_consistency!
      UserStat.update_view_counts(13.hours.ago)
    end
  end
end
