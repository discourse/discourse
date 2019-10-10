# frozen_string_literal: true

module Jobs

  class PurgeDeletedUploads < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      grace_period = SiteSetting.purge_deleted_uploads_grace_period_days
      Discourse.store.purge_tombstone(grace_period)
    end

  end

end
