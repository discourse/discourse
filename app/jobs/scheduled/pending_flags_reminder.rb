require_dependency 'flag_query'

module Jobs

  class PendingFlagsReminder < Jobs::Scheduled

    every 1.day

    def execute(args)
      if SiteSetting.notify_about_flags_after > 0 &&
         PostAction.flagged_posts_count > 0 &&
         FlagQuery.flagged_post_actions('active').where('post_actions.created_at < ?', 48.hours.ago).pluck(:id).count > 0

          message = PendingFlagsMailer.notify
          Email::Sender.new(message, :pending_flags_reminder).send
      end
    end

  end

end
