# frozen_string_literal: true

class AdminDashboardSystem
  STORAGE_REPORT = "storage_stats"
  private_constant :STORAGE_REPORT

  class << self
    def build(guardian:)
      new(guardian: guardian).build
    end
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
    DiscourseUpdates.check_version.as_json
  end

  def storage
    stats = storage_stats
    return nil if stats.blank?

    stats = stats.except(:backups) if !guardian.is_admin?

    stats.each_with_object({}) do |(store, values), result|
      result[store] = values.nil? ? nil : values.merge(remote: remote?(store))
    end
  end

  def remote?(store)
    case store.to_s
    when "backups"
      SiteSetting.backup_location == BackupLocationSiteSetting::S3
    when "uploads"
      Discourse.store.external?
    else
      false
    end
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
