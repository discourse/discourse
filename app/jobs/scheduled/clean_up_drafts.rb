module Jobs
  class CleanUpDrafts < Jobs::Scheduled
    every 1.week

    def execute(args)
      delete_drafts_older_than_n_days = SiteSetting.delete_drafts_older_than_n_days.days.ago

      # remove old drafts
      Draft.where("updated_at < ?", delete_drafts_older_than_n_days).destroy_all
    end
  end
end
