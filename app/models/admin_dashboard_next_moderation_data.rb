class AdminDashboardNextModerationData < AdminDashboardNextData
  def reports
    @reports ||= %w{
      flags_status
      post_edits
    }
  end

  def get_json
    {
      reports: self.class.reports(reports),
      updated_at: Time.zone.now.as_json
    }
  end

  def self.stats_cache_key
    'moderation-dashboard-data'
  end
end
