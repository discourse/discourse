# frozen_string_literal: true

module Jobs

  class EnqueueDigestEmails < ::Jobs::Scheduled
    every 30.minutes

    def execute(args)
      return if SiteSetting.disable_digest_emails? || SiteSetting.private_email?
      users = target_user_ids

      if users.length > GlobalSetting.max_digests_enqueued_per_30_mins_per_site
        users = users.shuffle[0...GlobalSetting.max_digests_enqueued_per_30_mins_per_site]
      end

      users.each do |user_id|
        ::Jobs.enqueue(:user_email, type: :digest, user_id: user_id)
      end
    end

    def target_user_ids
      # Users who want to receive digest email within their chosen digest email frequency
      query = User
        .real
        .activated
        .not_suspended
        .where(staged: false)
        .joins(:user_option, :user_stat, :user_emails)
        .where("user_options.email_digests")
        .where("user_stats.bounce_score < #{SiteSetting.bounce_score_threshold}")
        .where("user_emails.primary")
        .where("COALESCE(last_emailed_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 MINUTE'::INTERVAL * user_options.digest_after_minutes)")
        .where("COALESCE(last_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 MINUTE'::INTERVAL * user_options.digest_after_minutes)")
        .where("COALESCE(last_seen_at, '2010-01-01') >= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * #{SiteSetting.suppress_digest_email_after_days})")

      # If the site requires approval, make sure the user is approved
      query = query.where("approved OR moderator OR admin") if SiteSetting.must_approve_users?

      query.pluck(:id)
    end

  end

end
