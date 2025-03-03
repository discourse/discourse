# frozen_string_literal: true

module Jobs
  class DeleteRejectedEmails < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      Email::Cleaner.delete_rejected!
    end
  end
end
