# frozen_string_literal: true

module ::Jobs
  class CleanUpBlogReviewUploads < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless UpcomingChanges.enabled?(:blog_enabled)

      Blog::Review.release_inactive_uploads!
    end
  end
end
