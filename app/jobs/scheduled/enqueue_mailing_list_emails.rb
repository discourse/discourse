module Jobs

  class EnqueueMailingListEmails < Jobs::Scheduled

    every 30.minutes

    def execute(args)
      return if SiteSetting.disable_mailing_list_mode?
      target_user_ids.each do |user_id|
        Jobs.enqueue(:user_email, type: :mailing_list, user_id: user_id)
      end
    end

    def target_user_ids
      # Users who want to receive daily mailing list emails
      User.real
          .not_suspended
          .joins(:user_option)
          .where(active: true, staged: false, user_options: {mailing_list_mode: true, mailing_list_mode_frequency: 0})
          .where("#{!SiteSetting.must_approve_users?} OR approved OR moderator OR admin")
          .pluck(:id)
    end

  end

end
