# frozen_string_literal: true

class AdminDashboardGeneralData < AdminDashboardData
  def get_json
    {
      updated_at: Time.zone.now.as_json
    }
  end

  def self.stats_cache_key
    "general-dashboard-data-#{Report::SCHEMA_VERSION}"
  end
end
