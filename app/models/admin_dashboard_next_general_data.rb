class AdminDashboardNextGeneralData < AdminDashboardNextData
  def reports
    @reports ||= %w{
      page_view_total_reqs
      visits
      time_to_first_response
      likes
      flags
      user_to_user_private_messages_with_replies
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
