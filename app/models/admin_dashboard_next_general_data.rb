class AdminDashboardNextGeneralData < AdminDashboardNextData
  def reports
    @reports ||= %w{
      signups
      topics
      posts
      dau_by_mau
      daily_engaged_users
      new_contributors
      page_view_total_reqs
      visits
      time_to_first_response
      likes
      flags
      user_to_user_private_messages_with_replies
      top_referred_topics
      users_by_type
      users_by_trust_level
      trending_search
    }
  end

  def get_json
    {
      reports: self.class.reports(reports),
      updated_at: Time.zone.now.as_json
    }
  end

  def self.stats_cache_key
    'general-dashboard-data'
  end
end
