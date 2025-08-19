# frozen_string_literal: true

module Jobs
  class PurgeOldMiniSchedulerStat < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      MiniScheduler::Stat.purge_old
    end
  end
end
