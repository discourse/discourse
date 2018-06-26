class AdminDashboardNextData
  include StatsCacheable

  REPORTS = %w{
    page_view_total_reqs
    visits
    time_to_first_response
    likes
    flags
    user_to_user_private_messages_with_replies
  }

  def initialize(opts = {})
    @opts = opts
  end

  def self.fetch_stats
    AdminDashboardNextData.new.as_json
  end

  def self.stats_cache_key
    'dash-next-stats'
  end

  def as_json(_options = nil)
    @json ||= get_json
  end

  def get_json
    json = {
      reports: AdminDashboardNextData.reports(REPORTS),
      updated_at: Time.zone.now.as_json
    }

    if SiteSetting.enable_backups
      json[:last_backup_taken_at] = last_backup_taken_at
    end

    json
  end

  def last_backup_taken_at
    if last_backup = Backup.all.last
      File.ctime(last_backup.path).utc
    end
  end

  def self.reports(source)
    source.map { |type| Report.find(type).as_json }
  end
end
