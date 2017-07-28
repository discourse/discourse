module Jobs

  class CleanUpUnmatchedEmails < Jobs::Scheduled
    every 1.day

    def execute(args)
      last_match_threshold = SiteSetting.max_age_unmatched_emails.days.ago

      ScreenedEmail.where(action_type: ScreenedEmail.actions[:block])
        .where("last_match_at < ?", last_match_threshold)
        .destroy_all
    end

  end

end
