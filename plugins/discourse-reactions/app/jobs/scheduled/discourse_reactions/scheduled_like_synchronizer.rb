# frozen_string_literal: true

module Jobs
  module DiscourseReactions
    class ScheduledLikeSynchronizer < ::Jobs::Scheduled
      every 1.day

      def execute(args = {})
        ::Jobs.enqueue(Jobs::DiscourseReactions::LikeSynchronizer)
      end
    end
  end
end
