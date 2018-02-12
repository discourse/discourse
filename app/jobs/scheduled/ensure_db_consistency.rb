module Jobs
  # various consistency checks
  class EnsureDbConsistency < Jobs::Scheduled
    every 12.hours

    def execute(args)
      UserVisit.ensure_consistency!
      Group.ensure_consistency!
      Notification.ensure_consistency!
      UserAction.ensure_consistency!
      TopicFeaturedUsers.ensure_consistency!
      PostRevision.ensure_consistency!
      UserStat.ensure_consistency!(13.hours.ago)
      Topic.ensure_consistency!
      Badge.ensure_consistency!
      CategoryUser.ensure_consistency!
      UserOption.ensure_consistency!
      Tag.ensure_consistency!
      CategoryTagStat.ensure_consistency!
    end
  end
end
