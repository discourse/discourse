# frozen_string_literal: true

class AdminDashboardSystem
  STORAGE_REPORT = "storage_stats"
  private_constant :STORAGE_REPORT

  def self.build(guardian:)
    new(guardian: guardian).build
  end

  def initialize(guardian:)
    @guardian = guardian
  end

  def build
    {
      version: version,
      storage: storage,
      discourse_updated_at: Discourse.last_commit_date,
      dashboard_updated_at: AdminDashboardIndexData.fetch_cached_stats["updated_at"],
    }
  end

  private

  attr_reader :guardian

  def version
    return nil if !SiteSetting.version_checks?

    DiscourseUpdates.check_version.as_json
  end

  def storage
    stats = storage_stats
    return nil if stats.blank?

    guardian.is_admin? ? stats : stats.except(:backups)
  end

  def storage_stats
    cached = Report.find_cached(STORAGE_REPORT)
    return cached[:data] if cached.present?

    report = Report.find(STORAGE_REPORT)
    return nil if report.nil? || report.error.present?

    Report.cache(report)
    report.data
  end
end
