# frozen_string_literal: true

module Jobs
  class CleanUpEmailTokens < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      EmailToken
        .where('NOT confirmed AND expired')
        .where('created_at < ?', 1.month.ago)
        .delete_all
    end
  end
end
