class AdminDashboardNextIndexData < AdminDashboardNextData
  def get_json
    {
      updated_at: Time.zone.now.as_json
    }
  end

  def self.stats_cache_key
    "index-dashboard-data-#{Report::SCHEMA_VERSION}"
  end

  # TODO: problems should be loaded from this model
  # and not from a separate model/route
end
