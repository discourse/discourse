# This job will automatically act on records that have gone unhandled on a
# queue for a long time.
module Jobs
  class AutoQueueHandler < Jobs::Scheduled

    every 1.day

    def execute(args)
      return unless SiteSetting.auto_handle_queued_age.to_i > 0

      Reviewable
        .where(status: Reviewable.statuses[:pending])
        .where('created_at < ?', SiteSetting.auto_handle_queued_age.to_i.days.ago)
        .each do |reviewable|

        if reviewable.is_a?(ReviewableFlaggedPost)
          reviewable.perform(Discourse.system_user, :ignore)
        else
          reviewable.perform(Discourse.system_user, :reject)
        end
      end
    end
  end
end
