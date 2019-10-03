# frozen_string_literal: true

module Jobs

  class EnsureS3UploadsExistence < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.enable_s3_inventory
      Discourse.store.list_missing_uploads(skip_optimized: true)
    end
  end
end
