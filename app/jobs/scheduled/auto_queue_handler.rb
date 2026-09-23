# frozen_string_literal: true

# This job will automatically act on records that have gone unhandled on a
# queue for a long time.
module Jobs
  class AutoQueueHandler < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return if SiteSetting.auto_handle_queued_age.to_i.zero?

      Reviewable
        .pending
        .where("created_at < ?", SiteSetting.auto_handle_queued_age.to_i.days.ago)
        .find_each do |reviewable|
          if reviewable.is_a?(ReviewableFlaggedPost)
            reviewable.perform(
              Discourse.system_user,
              :ignore_and_do_nothing,
              expired: true,
              outcome_source: "automated",
            )
          elsif reviewable.is_a?(ReviewableQueuedPost)
            reviewable.perform(Discourse.system_user, :reject_post, outcome_source: "automated")
          elsif reviewable.is_a?(ReviewableUser)
            reviewable.perform(Discourse.system_user, :delete_user, outcome_source: "automated")
          end
        end
    end
  end
end
