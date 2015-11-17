module Jobs

  # A daily job that will enqueue digest emails to be sent to users
  class EnqueueDigestEmails < Jobs::Scheduled
    every 6.hours

    def execute(args)
      unless SiteSetting.disable_digest_emails?
        target_user_ids.each do |user_id|
          Jobs.enqueue(:user_email, type: :digest, user_id: user_id)
        end
      end
    end

    def target_user_ids
      # Users who want to receive emails and haven't been emailed in the last day
      query = User.real
                  .where(email_digests: true, active: true, staged: false)
                  .not_suspended
                  .where("COALESCE(last_emailed_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * digest_after_days)")
                  .where("(COALESCE(last_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * digest_after_days)) AND
                           COALESCE(last_seen_at, '2010-01-01') >= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * #{SiteSetting.suppress_digest_email_after_days})")

      # If the site requires approval, make sure the user is approved
      if SiteSetting.must_approve_users?
        query = query.where("approved OR moderator OR admin")
      end

      query.pluck(:id)
    end

  end

end
