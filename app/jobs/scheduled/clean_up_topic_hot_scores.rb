# frozen_string_literal: true

module Jobs
  class CleanUpTopicHotScores < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      TopicHotScore.cleanup!
    end
  end
end
