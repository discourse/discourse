require 'disk_space'

class Admin::DashboardNextController < Admin::AdminController
  def index
    data = AdminDashboardNextIndexData.fetch_cached_stats

    if SiteSetting.version_checks?
      data.merge!(version_check: DiscourseUpdates.check_version.as_json)
    end

    render json: data
  end

  def moderation; end

  def general
    data = AdminDashboardNextGeneralData.fetch_cached_stats

    if SiteSetting.enable_backups
      data[:last_backup_taken_at] = last_backup_taken_at
      data[:disk_space] = DiskSpace.cached_stats
    end

    render json: data
  end

  private

  def last_backup_taken_at
    if last_backup = Backup.all.first
      File.ctime(last_backup.path).utc
    end
  end
end
