# frozen_string_literal: true

module Jobs
  # This job will run on a regular basis to update statistics and denormalized data.
  # If it does not run, the site will not function properly.
  class Weekly < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      ScoreCalculator.new.calculate
      MiniScheduler::Stat.purge_old
      Draft.cleanup!
      UserAuthToken.cleanup!
      Email::Cleaner.delete_rejected!
      Notification.purge_old!
      Bookmark.cleanup!
    end
  end
end
