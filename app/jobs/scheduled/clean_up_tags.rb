# frozen_string_literal: true

module Jobs
  class CleanUpTags < ::Jobs::Scheduled
    every 1.day

    GRACE_PERIOD_MINUTES = 5

    def execute(args)
      return unless SiteSetting.automatically_clean_unused_tags
      Tag.transaction do
        tags = Tag.unused.where("tags.created_at < ?", GRACE_PERIOD_MINUTES.minutes.ago)
        StaffActionLogger.new(Discourse.system_user).log_custom(
          "deleted_unused_tags",
          tags: tags.pluck(:name),
        )
        tags.destroy_all
      end
    end
  end
end
