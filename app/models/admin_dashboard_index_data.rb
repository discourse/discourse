# frozen_string_literal: true

class AdminDashboardIndexData < AdminDashboardData
  class << self
    def stats_cache_key
      "index-dashboard-data-#{Report::SCHEMA_VERSION}"
    end
  end

  def get_json
    { updated_at: Time.zone.now.as_json }
  end

  # TODO: problems should be loaded from this model
  # and not from a separate model/route
end
