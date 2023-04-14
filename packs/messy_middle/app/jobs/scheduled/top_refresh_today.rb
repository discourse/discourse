# frozen_string_literal: true

module Jobs
  class TopRefreshToday < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      TopTopic.refresh_daily!
    end
  end
end
