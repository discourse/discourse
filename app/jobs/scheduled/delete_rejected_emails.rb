# frozen_string_literal: true

module Jobs
  class DeleteRejectedEmails < ::Jobs::Scheduled
    every 1.month
    sidekiq_options retry: false

    def execute(args)
      IncomingEmail.delete_by('rejection_message IS NOT NULL AND created_at < ?', SiteSetting.delete_rejected_email_after_days.days.ago)
    end
  end
end
