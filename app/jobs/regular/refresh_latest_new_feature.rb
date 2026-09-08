# frozen_string_literal: true

module Jobs
  # Deriving the newest new-feature timestamp filters the feed against the
  # installed version, which can shell out to git, so it never happens inline
  # during a request.
  class RefreshLatestNewFeature < ::Jobs::Base
    def execute(args)
      DiscourseUpdates.refresh_latest_new_feature_created_at!
    end
  end
end
