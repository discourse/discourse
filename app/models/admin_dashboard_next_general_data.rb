class AdminDashboardNextGeneralData < AdminDashboardNextData
  def reports
    @reports ||= %w{
      users_by_type
      users_by_trust_level
    }
  end

  def get_json
    {
      reports: self.class.reports(reports).compact,
      updated_at: Time.zone.now.as_json
    }
  end

  def self.stats_cache_key
    "general-dashboard-data-#{Report::SCHEMA_VERSION}"
  end
end
