module Jobs

  class PurgeDeletedUploads < Jobs::Scheduled
    recurrence { daily }

    def execute(args)
      grace_period = SiteSetting.purge_deleted_uploads_grace_period_days
      Discourse.store.purge_tombstone(grace_period)
    end

  end

end
