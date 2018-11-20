module Jobs

  class EnqueueDigestEmails < Jobs::Scheduled
    every 30.minutes

    def execute(args)
      return if SiteSetting.disable_digest_emails? || SiteSetting.private_email?
      target_user_ids.each do |user_id|
        Jobs.enqueue(:user_email, type: :digest, user_id: user_id)
      end
    end

    def target_user_ids
      # Users who want to receive digest email within their chosen digest email frequency
      query = User.real
        .not_suspended
        .activated
        .where(staged: false)
        .joins(:user_option, :user_stat)
        .where("user_options.email_digests")
        .where("user_stats.bounce_score < #{SiteSetting.bounce_score_threshold}")
        .where("COALESCE(last_emailed_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 MINUTE'::INTERVAL * user_options.digest_after_minutes)")
        .where("COALESCE(last_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 MINUTE'::INTERVAL * user_options.digest_after_minutes)")
        .where("COALESCE(last_seen_at, '2010-01-01') >= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * #{SiteSetting.suppress_digest_email_after_days})")

      # If the site requires approval, make sure the user is approved
      query = query.where("approved OR moderator OR admin") if SiteSetting.must_approve_users?

      query.pluck(:id)
    end

  end

end
