# frozen_string_literal: true

module Jobs
  class VerifyBrowserPageviewSessionRollup < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      BrowserPageviewSessionRollupSummary.verify_recent!(date: 2.days.ago.to_date)
    end
  end
end
