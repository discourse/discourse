# frozen_string_literal: true

module Jobs
  class TopRefreshOlder < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      TopTopic.refresh_older!
    end
  end
end
