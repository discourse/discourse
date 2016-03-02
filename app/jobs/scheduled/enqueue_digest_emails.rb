module Jobs

  # A daily job that will enqueue digest emails to be sent to users
  class EnqueueDigestEmails < Jobs::Scheduled
    every 30.minutes

    def execute(args)
      unless SiteSetting.disable_digest_emails?
        target_user_ids.each do |user_id|
          Jobs.enqueue(:user_email, type: :digest, user_id: user_id)
        end
      end
    end

    def target_user_ids
      # Users who want to receive digest email within their chosen digest email frequency
      query = User.real
                  .where(active: true, staged: false)
                  .joins(:user_option)
                  .not_suspended
                  .where(user_options: {email_digests: true})
                  .where("COALESCE(last_emailed_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 MINUTE'::INTERVAL * user_options.digest_after_minutes)")
                  .where("COALESCE(last_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 MINUTE'::INTERVAL * user_options.digest_after_minutes)")
                  .where("COALESCE(last_seen_at, '2010-01-01') >= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * #{SiteSetting.delete_digest_email_after_days})")

      # If the site requires approval, make sure the user is approved
      if SiteSetting.must_approve_users?
        query = query.where("approved OR moderator OR admin")
      end

      query.pluck(:id)
    end

  end

end
