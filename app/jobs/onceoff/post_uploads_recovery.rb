# frozen_string_literal: true

module Jobs
  class PostUploadsRecovery < ::Jobs::Onceoff
    MIN_PERIOD = 30
    MAX_PERIOD = 120

    def execute_onceoff(args)
      UploadRecovery.new.recover(Post.where(
        "baked_at >= ?",
        grace_period.days.ago
      ))
    end

    def grace_period
      SiteSetting.purge_deleted_uploads_grace_period_days.clamp(
        MIN_PERIOD,
        MAX_PERIOD
      )
    end
  end
end
