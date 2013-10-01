module Jobs

  # A daily job that will enqueue digest emails to be sent to users
  class EnqueueDigestEmails < Jobs::Scheduled
    recurrence { daily.hour_of_day(6) }

    def execute(args)
      target_user_ids.each do |user_id|
        Jobs.enqueue(:user_email, type: :digest, user_id: user_id)
      end
    end

    def target_user_ids
      # Users who want to receive emails and haven't been emailed in the last day
      query = User.real
                  .where(email_digests: true, active: true)
                  .where("COALESCE(last_emailed_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * digest_after_days)")
                  .where("(COALESCE(last_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * digest_after_days)) OR
                          email_always")

      # If the site requires approval, make sure the user is approved
      if SiteSetting.must_approve_users?
        query = query.where("approved OR moderator OR admin")
      end

      query.pluck(:id)
    end

  end

end
