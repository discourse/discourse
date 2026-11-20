# frozen_string_literal: true

# This job will automatically act on records that have gone unhandled on a
# queue for a long time.
module Jobs
  class AutoQueueHandler < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      age = SiteSetting.auto_handle_queued_age.to_i
      return if age.zero?

      cutoff = age.days.ago
      recently_reopened =
        ReviewableHistory
          .transitioned
          .pending
          .where(created_at: cutoff..)
          .where("reviewable_histories.reviewable_id = reviewables.id")

      Reviewable
        .pending
        .where("created_at < ?", cutoff)
        .where.not(recently_reopened.arel.exists)
        .find_each do |reviewable|
          if reviewable.is_a?(ReviewableFlaggedPost)
            reviewable.perform(Discourse.system_user, :ignore_and_do_nothing, expired: true)
          elsif reviewable.is_a?(ReviewableQueuedPost)
            reviewable.perform(Discourse.system_user, :reject_post)
          elsif reviewable.is_a?(ReviewableUser)
            reviewable.perform(Discourse.system_user, :delete_user)
          end
        end
    end
  end
end
