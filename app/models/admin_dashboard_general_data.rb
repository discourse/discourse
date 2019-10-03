# frozen_string_literal: true

class AdminDashboardGeneralData < AdminDashboardData
  def get_json
    days_since_update = Discourse.last_commit_date ? ((DateTime.now - Discourse.last_commit_date) / 1.day).to_i : nil
    {
      updated_at: Time.zone.now.as_json,
      discourse_updated_at: Discourse.last_commit_date,
      release_notes_link: "https://meta.discourse.org/c/feature/announcements?tags=release-notes&before=#{days_since_update}"
    }
  end

  def self.stats_cache_key
    "general-dashboard-data-#{Report::SCHEMA_VERSION}"
  end
end
